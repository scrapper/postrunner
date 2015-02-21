#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivitiesDB.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'
require 'yaml'

require 'fit4ruby'
require 'postrunner/Activity'
require 'postrunner/PersonalRecords'
require 'postrunner/ActivityListView'

module PostRunner

  class ActivitiesDB

    attr_reader :db_dir, :cfg, :fit_dir, :html_dir, :activities

    def initialize(db_dir, cfg)
      @db_dir = db_dir
      @cfg = cfg
      @fit_dir = File.join(@db_dir, 'fit')
      @html_dir = File.join(@db_dir, 'html')
      @archive_file = File.join(@db_dir, 'archive.yml')

      create_directories
      begin
        if File.exists?(@archive_file)
          @activities = YAML.load_file(@archive_file)
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

      @records = PersonalRecords.new(self)
      sync if sync_needed
    end

    # Add a new FIT file to the database.
    # @param fit_file [String] Name of the FIT file.
    # @return [TrueClass or FalseClass] True if the file could be added. False
    # otherwise.
    def add(fit_file)
      base_fit_file = File.basename(fit_file)
      if @activities.find { |a| a.fit_file == base_fit_file }
        Log.debug "Activity #{fit_file} is already included in the archive"
        return false
      end

      if File.exists?(File.join(@fit_dir, base_fit_file))
        Log.debug "Activity #{fit_file} has been deleted before"
        return false
      end

      begin
        fit_activity = Fit4Ruby.read(fit_file)
      rescue Fit4Ruby::Error
        Log.error $!
        return false
      end

      begin
        FileUtils.cp(fit_file, @fit_dir)
      rescue StandardError
        Log.fatal "Cannot copy #{fit_file} into #{@fit_dir}: #{$!}"
      end

      @activities << (activity = Activity.new(self, base_fit_file,
                                              fit_activity))
      @activities.sort! do |a1, a2|
        a2.timestamp <=> a1.timestamp
      end

      activity.register_records(@records)

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
      Log.info "#{fit_file} successfully added to archive"

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
      sync
    end

    def check
      @activities.each { |a| a.check }
      # Ensure that HTML index is up-to-date.
      ActivityListView.new(self).update_html_index
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
      ActivityListView.new(self).update_html_index
      show_in_browser(File.join(@html_dir, 'index.html'))
    end

    def list
      puts ActivityListView.new(self).to_s
    end

    def show_records
      puts @records.to_s
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
      ActivityListView.new(self).update_html_index
      Log.info "HTML index files have been updated."
    end

    private

    def sync
      begin
        File.open(@archive_file, 'w') { |f| f.write(@activities.to_yaml) }
      rescue StandardError
        Log.fatal "Cannot write archive file '#{@archive_file}': #{$!}"
      end

      @records.sync
      ActivityListView.new(self).update_html_index
    end

    def create_directories
      create_directory(@db_dir, 'data')
      create_directory(@fit_dir, 'fit')
      create_directory(@html_dir, 'html')

      create_symlink('icons')
      create_symlink('jquery')
      create_symlink('flot')
      create_symlink('openlayers')
    end

    def create_directory(dir, name)
      return if Dir.exists?(dir)

      Log.info "Creating #{name} directory #{dir}"
      begin
        Dir.mkdir(dir)
      rescue StandardError
        Log.fatal "Cannot create #{name} directory #{dir}: #{$!}"
      end
    end

    def create_symlink(dir)
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
      dst_dir = File.join(@html_dir, dir)
      unless File.exists?(dst_dir)
        begin
          FileUtils.ln_s(src_dir, dst_dir)
        rescue IOError
          Log.fatal "Cannot create symbolic link to '#{dst_dir}': #{$!}"
        end
      end
    end

  end

end

