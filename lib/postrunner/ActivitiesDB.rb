#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivitiesDB.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'
require 'yaml'

require 'fit4ruby'
require 'postrunner/BackedUpFile'
require 'postrunner/Activity'
require 'postrunner/PersonalRecords'
require 'postrunner/ActivityListView'
require 'postrunner/ViewButtons'

module PostRunner

  class ActivitiesDB

    attr_reader :db_dir, :cfg, :fit_dir, :activities, :records, :views

    def initialize(db_dir, cfg)
      @db_dir = db_dir
      @cfg = cfg
      @fit_dir = File.join(@db_dir, 'fit')
      @archive_file = File.join(@db_dir, 'archive.yml')
      @auxilliary_dirs = %w( icons jquery flot openlayers postrunner )

      create_directories
      begin
        if File.exists?(@archive_file)
          if RUBY_VERSION >= '3.1.0'
            # Since Ruby 3.1.0 YAML does not load unknown classes unless
            # explicitely listed.
            @activities = YAML.load_file(
              @archive_file, permitted_classes: [ PostRunner::Activity, Time ])
          else
            @activities = YAML.load_file(@archive_file)
          end
        else
          @activities = []
        end
      rescue RuntimeError
        Log.fatal "Cannot load archive file '#{@archive_file}': #{$!}"
      end

      unless @activities.is_a?(Array)
        Log.fatal "The archive file '#{@archive_file}' is corrupted"
      end

      # Not all instance variables of Activity are stored in the file. The
      # normal constructor is not run during YAML::load_file. We have to
      # initialize those instance variables in a secondary step.
      sync_needed = false
      @activities.each do |a|
        a.late_init(self)
        # If the Activity has the data from the FIT file loaded, a value was
        # missing in the YAML file. Set the sync flag so we can update the
        # YAML file once we have checked all Activities.
        sync_needed |= !a.fit_activity.nil?
      end

      # Define which View objects the HTML output will contain off. This
      # doesn't really belong in ActivitiesDB but for now it's the best place
      # to put it.
      @views = ViewButtons.new([
        NavButtonDef.new('activities.png', 'index.html'),
        NavButtonDef.new('record.png', "records-0.html")
      ])

      sync if sync_needed
    end

    # Ensure that all necessary directories are present to store the output
    # files. This method is idempotent and can be called even when directories
    # exist already.
    def create_directories
      @cfg.create_directory(@db_dir, 'data')
      @cfg.create_directory(@fit_dir, 'fit')
      @cfg.create_directory(@cfg[:html_dir], 'html')

      @auxilliary_dirs.each do |dir|
        create_auxdir(dir)
      end
    end

    # Add a new FIT file to the database.
    # @param fit_file_name [String] Name of the FIT file.
    # @param fit_activity [Activity] Activity to add
    # @return [TrueClass or FalseClass] True if the file could be added. False
    # otherwise.
    def add(fit_file_name, fit_activity)
      base_fit_file_name = File.basename(fit_file_name)

      if @activities.find { |a| a.fit_file == base_fit_file_name }
        Log.debug "Activity #{fit_file_name} is already included in the archive"
        return false
      end

      if File.exists?(File.join(@fit_dir, base_fit_file_name))
        Log.debug "Activity #{fit_file_name} has been deleted before"
        return false
      end

      begin
        FileUtils.cp(fit_file_name, @fit_dir)
      rescue StandardError
        Log.fatal "Cannot copy #{fit_file_name} into #{@fit_dir}: #{$!}"
      end

      @activities << (activity = Activity.new(self, base_fit_file_name,
                                              fit_activity))
      @activities.sort! do |a1, a2|
        a2.timestamp <=> a1.timestamp
      end

      activity.register_records

      # Generate HTML file for this activity.
      activity.generate_html_view

      # The HTML activity views contain links to their predecessors and
      # successors. After inserting a new activity, we need to re-generate
      # these views as well.
      if (pred = predecessor(activity))
        pred.generate_html_view
      end
      if (succ = successor(activity))
        succ.generate_html_view
      end

      sync
      Log.info "#{fit_file_name} successfully added to archive"

      true
    end

    def delete(activity)
      pred = predecessor(activity)
      succ = successor(activity)

      @activities.delete(activity)

      # The HTML activity views contain links to their predecessors and
      # successors. After deleting an activity, we need to re-generate these
      # views as well.
      pred.generate_html_view if pred
      succ.generate_html_view if succ

      sync
    end

    def rename(activity, name)
      activity.rename(name)
      sync
    end

    def set(activity, attribute, value)
      activity.set(attribute, value)
      if %w( norecord type ).include?(attribute)
        # If we have changed a norecord setting or an activity type, we need
        # to regenerate all reports and re-collect the record list since we
        # don't know which Activity needs to replace the changed one.
        check
      end
      sync
    end

    def ref_by_fit_file(fit_file)
      i = 1
      @activities.each do |activity|
        return i if activity.fit_file == fit_file
        i += 1
      end

      nil
    end

    def activity_by_fit_file(fit_file)
      @activities.find { |a| a.fit_file == fit_file }
    end

    def find(query)
      case query
      when /\A-?\d+$\z/
        index = query.to_i
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        index -= 1 if index > 0
        if (a = @activities[index])
          return [ a ]
        end
      when /\A-?\d+--?\d+\z/
        idxs = query.match(/(?<sidx>-?\d+)-(?<eidx>-?[0-9]+)/)
        sidx = idxs['sidx'].to_i
        eidx = idxs['eidx'].to_i
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        sidx -= 1 if sidx > 0
        eidx -= 1 if eidx > 0
        unless (as = @activities[sidx..eidx]).empty?
          return as
        end
      else
        Log.error "Invalid activity query: #{query}"
      end

      []
    end

    # Return the next Activity after the provided activity. Note that this has
    # a lower index. If none is found, return nil.
    def successor(activity)
      idx = @activities.index(activity)
      return nil if idx.nil? || idx == 0
      @activities[idx - 1]
    end

    # Return the previous Activity before the provided activity.
    # If none is found, return nil.
    def predecessor(activity)
      idx = @activities.index(activity)
      return nil if idx.nil?
      # Activities indexes are reversed. The predecessor has a higher index.
      @activities[idx + 1]
    end

    def map_to_files(query)
      case query
      when /\A-?\d+$\z/
        index = query.to_i
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        index -= 1 if index > 0
        if (a = @activities[index])
          return [ File.join(@fit_dir, a.fit_file) ]
        end
      when /\A-?\d+--?\d+\z/
        idxs = query.match(/(?<sidx>-?\d+)-(?<eidx>-?[0-9]+)/)
        sidx = idxs['sidx'].to_i
        eidx = idxs['eidx'].to_i
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        sidx -= 1 if sidx > 0
        eidx -= 1 if eidx > 0
        unless (as = @activities[sidx..eidx]).empty?
          files = []
          as.each do |a|
            files << File.join(@fit_dir, a.fit_file)
          end
          return files
        end
      else
        Log.error "Invalid activity query: #{query}"
      end

      []
    end

    # Show the activity list in a web browser.
    def show_list_in_browser
      ActivityListView.new(self).update_index_pages
      show_in_browser(File.join(@cfg[:html_dir], 'index.html'))
    end

    def list
      puts ActivityListView.new(self).to_s
    end

    # Launch a web browser and show an HTML file.
    # @param html_file [String] file name of the HTML file to show
    def show_in_browser(html_file)
      cmd = "#{ENV['BROWSER'] || 'firefox'} \"#{html_file}\" &"

      unless system(cmd)
        Log.fatal "Failed to execute the following shell command: #{$cmd}\n" +
                  "#{$!}"
      end
    end

    # This method can be called to re-generate all HTML reports and all HTML
    # index files.
    def generate_all_html_reports
      Log.info "Re-generating all HTML report files..."
      # Generate HTML views for all activities in the DB.
      @activities.each { |a| a.generate_html_view }
      Log.info "All HTML report files have been re-generated."
      # (Re-)generate index files.
      ActivityListView.new(self).update_index_pages
      Log.info "HTML index files have been updated."
    end

    # Take all necessary steps to convert user data to match an updated
    # PostRunner version.
    def handle_version_update
      # An updated version may bring new auxilliary directories. We remove the
      # old directories and create new copies.
      Log.warn('Removing old HTML auxilliary directories')
      @auxilliary_dirs.each do |dir|
        auxdir = File.join(@cfg[:html_dir], dir)
        FileUtils.rm_rf(auxdir)
      end
      create_directories

      Log.warn('Updating HTML files...')
      generate_all_html_reports
    end

    private

    def sync
      begin
        BackedUpFile.open(@archive_file, 'w') do |f|
          f.write(@activities.to_yaml)
        end
      rescue StandardError
        Log.fatal "Cannot write archive file '#{@archive_file}': #{$!}"
      end

      ActivityListView.new(self).update_index_pages
    end

    def create_auxdir(dir)
      # This file should be in lib/postrunner. The 'misc' directory should be
      # found in '../../misc'.
      misc_dir = File.realpath(File.join(File.dirname(__FILE__),
                                         '..', '..', 'misc'))
      unless Dir.exists?(misc_dir)
        Log.fatal "Cannot find 'misc' directory under '#{misc_dir}': #{$!}"
      end
      src_dir = File.join(misc_dir, dir)
      unless Dir.exists?(src_dir)
        Log.fatal "Cannot find '#{src_dir}': #{$!}"
      end
      dst_dir = @cfg[:html_dir]

      begin
        #FileUtils.ln_s(src_dir, dst_dir)
        FileUtils.cp_r(src_dir, dst_dir)
      rescue IOError
        Log.fatal "Cannot copy auxilliary data directory '#{dst_dir}': #{$!}"
      end
    end

  end

end

