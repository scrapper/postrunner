#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Main.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'fit4ruby'
require 'perobs'

require 'postrunner/version'
require 'postrunner/Log'
require 'postrunner/DirUtils'
require 'postrunner/RuntimeConfig'
require 'postrunner/FitFileStore'
require 'postrunner/PersonalRecords'
require 'postrunner/ActivitiesDB'
require 'postrunner/MonitoringDB'
require 'postrunner/EPO_Downloader'

module PostRunner

  class Main

    include DirUtils

    def initialize
      @filter = nil
      @name = nil
      @force = false
      @attribute = nil
      @value = nil
      @db_dir = File.join(ENV['HOME'], '.postrunner')
    end

    def main(args)
      return 0 if (args = parse_options(args)).nil?

      unless $DEBUG
        Kernel.trap('INT') do
          begin
            Log.fatal('Aborting on user request!')
          rescue RuntimeError
            exit 1
          end
        end
      end

      begin
        create_directory(@db_dir, 'PostRunner data')
        @db = PEROBS::Store.new(File.join(@db_dir, 'database'))
        # Create a hash to store configuration data in the store unless it
        # exists already.
        cfg = (@db['config'] ||= @db.new(PEROBS::Hash))
        cfg['unit_system'] ||= :metric
        cfg['version'] ||= VERSION
        # We always override the data_dir as the user might have moved the data
        # directory. The only reason we store it in the DB is to have it
        # available throught the application.
        cfg['data_dir'] = @db_dir
        # Always update html_dir setting so that the DB directory can be moved
        # around by the user.
        cfg['html_dir'] = File.join(@db_dir, 'html')

        setup_directories
        if $DEBUG && (errors = @db.check) != 0
          Log.abort "Postrunner database is corrupted: #{errors} errors found"
        end
        return execute_command(args)

      rescue Exception => e
        if e.is_a?(SystemExit) || e.is_a?(Interrupt)
          $stderr.puts e.backtrace.join("\n") if $DEBUG
        elsif e.is_a?(Fit4Ruby::Abort)
          # Programm execution error that does not warrant a backtrace to be
          # printed.
          return -1
        else
          Log.error("#{e}\n#{e.backtrace.join("\n")}\n\n" +
                    "#{'*' * 79}\nYou have triggered a bug in PostRunner " +
                    "#{VERSION}!")
        end
        return -1
      end
    end

    private

    def parse_options(args)
      parser = OptionParser.new do |opts|
        opts.banner = "Usage postrunner <command> [options]"

        opts.separator <<"EOT"

Copyright (c) 2014, 2015, 2016 by Chris Schlaeger

This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.
EOT

        opts.separator ""
        opts.separator "Options for the 'dump' command:"
        opts.on('--filter-msg N', Integer,
                'Only dump messages of type number N') do |n|
          @filter = Fit4Ruby::FitFilter.new unless @filter
          @filter.record_numbers = [] unless @filter.record_numbers
          @filter.record_numbers << n.to_i
        end
        opts.on('--filter-msg-idx N', Integer,
                'Only dump the N-th message of the specified types') do |n|
          @filter = Fit4Ruby::FitFilter.new unless @filter
          @filter.record_indexes = [] unless @filter.record_indexes
          @filter.record_indexes << n.to_i
        end
        opts.on('--filter-field name', String,
                'Only dump the field \'name\' of the selected messages') do |n|
          @filter = Fit4Ruby::FitFilter.new unless @filter
          @filter.field_names = [] unless @filter.field_names
          @filter.field_names << n
        end
        opts.on('--filter-undef',
                "Don't show fields with undefined values") do
          @filter = Fit4Ruby::FitFilter.new unless @filter
          @filter.ignore_undef = true
        end
        opts.on('--force',
                'Import files even if they have been deleted from the ' +
                'database before.') do
          @force = true
        end

        opts.separator ""
        opts.separator "Options for the 'import' command:"
        opts.on('--name name', String,
                'Name the activity to the specified name') do |n|
          @name = n
        end

        opts.separator ""
        opts.separator "General options:"
        opts.on('--dbdir dir', String,
                'Directory for the activity database and related files') do |d|
          @db_dir = d
        end
        opts.on('--debug', 'Enable debug mode') do
          $DEBUG = true
        end
        opts.on('-v', '--verbose',
                'Show internal messages helpful for debugging problems') do
          Log.level = Logger::DEBUG
        end
        opts.on('-h', '--help', 'Show this message') do
          $stderr.puts opts
          return nil
        end
        opts.on('--version', 'Show version number') do
          puts VERSION
          return nil
        end

        opts.separator <<"EOT"

Commands:

check [ <fit file> | <ref> ... ]
           Check the provided FIT file(s) for structural errors. If no file or
           reference is provided, the complete archive is checked.

dump <fit file> | <ref>
           Dump the content of the FIT file.

events [ <ref> ]
           List all the events of the specified activies.

import [ <fit file> | <directory> ]
           Import the provided FIT file(s) into the postrunner database. If no
           file or directory is provided, the directory that was used for the
           previous import is being used.

daily [ <date> ]
           Print a report summarizing the current day or the specified day.

delete <ref>
           Delete the activity from the archive.

list
           List all FIT files stored in the data base.

monthly [ <date> ]
           Print a table with various statistics for each day of the specified
           month.

records
           List all personal records.

rename <new name> <ref>
           For the specified activities replace current activity name with a
           new name that describes the activity. By default the activity name
           matches the FIT file name.

set <attribute> <value> <ref>
           For the specified activies set the attribute to the given value. The
           following attributes are supported:

           name:     The activity name (defaults to FIT file name)
           norecord: Ignore all records from this activity (value must true
                     or false)
           note:     A comment or summary of the activity
           type:     The type of the activity
           subtype:  The subtype of the activity

show [ <ref> ]
           Show the referenced FIT activity in a web browser. If no reference
           is provided show the list of activities in the database.

sources [ <ref> ]
           Show the data sources for the various measurements and how they
           changed during the course of the activity.

summary <ref>
           Display the summary information for the FIT file.

units <metric | statute>
           Change the unit system.

htmldir <directory>
           Change the output directory for the generated HTML files

update-gps Download the current set of GPS Extended Prediction Orbit (EPO)
           data and store them on the device.


<fit file> An absolute or relative name of a .FIT file.

<ref>      The index or a range of indexes to activities in the database.
           :1 is the newest imported activity
           :-1 is the oldest imported activity
           :1-2 refers to the first and second activity in the database
           :1--1 refers to all activities
EOT

      end

      begin
        parser.parse!(args)
      rescue OptionParser::InvalidOption
        Log.error "#{$!}\n" + help
        return nil
      end
    end

    def setup_directories
      create_directory(@db['config']['html_dir'], 'HTML output')

      %w( icons jquery flot openlayers postrunner ).each do |dir|
        # This file should be in lib/postrunner. The 'misc' directory should be
        # found in '../../misc'.
        misc_dir = File.realpath(File.join(File.dirname(__FILE__),
                                           '..', '..', 'misc'))
        unless Dir.exists?(misc_dir)
          Log.abort "Cannot find 'misc' directory under '#{misc_dir}': #{$!}"
        end
        src_dir = File.join(misc_dir, dir)
        unless Dir.exists?(src_dir)
          Log.abort "Cannot find '#{src_dir}': #{$!}"
        end
        dst_dir = @db['config']['html_dir']

        begin
          FileUtils.cp_r(src_dir, dst_dir)
        rescue IOError
          Log.abort "Cannot copy auxilliary data directory '#{dst_dir}': #{$!}"
        end
      end
    end

    def execute_command(args)
      # Create or load the FitFileStore data.
      unless (@ffs = @db['file_store'])
        @ffs = @db['file_store'] = @db.new(FitFileStore)
      end
      # Create or load the PersonalRecords data.
      unless (@records = @db['records'])
        @records = @db['records'] = @db.new(PersonalRecords)
      end
      handle_version_update
      import_legacy_archive

      case (cmd = args.shift)
      when 'check'
        if args.empty?
          @db.check(true)
          @ffs.check
          Log.info "Datebase cleanup started. Please wait ..."
          @db.gc
          Log.info "Database cleanup finished"
        else
          process_files_or_activities(args, :check)
        end
      when 'daily'
        # Get the date of requested day in 'YY-MM-DD' format. If no argument
        # is given, use the current date.
        @ffs.daily_report(day_in_localtime(args, '%Y-%m-%d'))
      when 'monthly'
        # Get the date of requested day in 'YY-MM-DD' format. If no argument
        # is given, use the current date.
        @ffs.monthly_report(day_in_localtime(args, '%Y-%m-01'))
      when 'delete'
        process_activities(args, :delete)
      when 'dump'
        @filter = Fit4Ruby::FitFilter.new unless @filter
        process_files_or_activities(args, :dump)
      when 'events'
        process_files_or_activities(args, :events)
      when 'import'
        if args.empty?
          # If we have no file or directory for the import command, we get the
          # most recently used directory from the runtime config.
          process_files([ @db['config']['import_dir']  ], :import)
        else
          process_files(args, :import)
          if args.length == 1 && Dir.exists?(args[0])
            # If only one directory was specified as argument we store the
            # directory for future use.
            @db['config']['import_dir'] = args[0]
          end
        end
      when 'list'
        @ffs.list_activities
      when 'records'
        puts @records.to_s
      when 'rename'
        unless (@name = args.shift)
          Log.abort 'You must provide a new name for the activity'
        end
        process_activities(args, :rename)
      when 'set'
        unless (@attribute = args.shift)
          Log.abort 'You must specify the attribute you want to change'
        end
        unless (@value = args.shift)
          Log.abort 'You must specify the new value for the attribute'
        end
        process_activities(args, :set)
      when 'show'
        if args.empty?
          @ffs.show_list_in_browser
        else
          process_activities(args, :show)
        end
      when 'sources'
        process_activities(args, :sources)
      when 'summary'
        process_activities(args, :summary)
      when 'units'
        change_unit_system(args)
      when 'htmldir'
        change_html_dir(args)
      when 'update-gps'
        update_gps_data
      when nil
        Log.abort("No command provided. " + help)
      else
        Log.abort("Unknown command '#{cmd}'. " + help)
      end

      # Ensure that all updates are written to the database.
      @db.sync

      0
    end

    def help
      "See 'postrunner -h' for more information."
    end

    def process_files_or_activities(files_or_activities, command)
      files_or_activities.each do |foa|
        if foa[0] == ':'
          process_activities([ foa ], command)
        else
          process_files([ foa ], command)
        end
      end
    end

    def process_activities(activity_refs, command)
      if activity_refs.empty?
        Log.abort("You must provide at least one activity reference.")
      end

      activity_refs.each do |a_ref|
        if a_ref[0] == ':'
          activities = @ffs.find(a_ref[1..-1])
          if activities.empty?
            Log.warn "No matching activities found for '#{a_ref}'"
            return
          end
          activities.each { |a| process_activity(a, command) }
        else
          Log.abort "Activity references must start with ':': #{a_ref}"
        end
      end

      nil
    end

    def process_files(files_or_dirs, command)
      if files_or_dirs.empty?
        Log.abort("You must provide at least one .FIT file name.")
      end

      files_or_dirs.each do |fod|
        if File.directory?(fod)
          Dir.glob(File.join(fod, '*.FIT')).each do |file|
            process_file(file, command)
          end
        else
          process_file(fod, command)
        end
      end
    end

    # Process a single FIT file according to the given command.
    # @param file [String] File name of a FIT file
    # @param command [Symbol] Processing instruction
    # @return [TrueClass, FalseClass] true if command was successful, false
    #         otherwise
    def process_file(file, command)
      case command
      when :check, :dump
        read_fit_file(file)
      when :import
        import_fit_file(file)
      else
        Log.fatal("Unknown file command #{command}")
      end
    end

    # Import the given FIT file.
    # @param fit_file_name [String] File name of the FIT file
    # @return [TrueClass, FalseClass] true if file was successfully imported,
    #         false otherwise
    def import_fit_file(fit_file_name)
      begin
        fit_entity = Fit4Ruby.read(fit_file_name)
      rescue Fit4Ruby::Error
        Log.error $!
        return false
      end

      if fit_entity.is_a?(Fit4Ruby::Activity) ||
         fit_entity.is_a?(Fit4Ruby::Monitoring_B)
        return @ffs.add_fit_file(fit_file_name, fit_entity, @force)
      else
        Log.error "#{fit_file_name} is not a recognized FIT file"
        return false
      end
    end

    def process_activity(activity, command)
      case command
      when :check
        activity.check
      when :delete
        @ffs.delete_activity(activity)
      when :dump
        activity.dump(@filter)
      when :events
        activity.events
      when :rename
        @ffs.rename_activity(activity, @name)
      when :set
        if @attribute == 'name'
          # We have to handle the 'name' attribute as special case as we have
          # to update some HTML reports as well.
          @ffs.rename_activity(activity, @value)
        else
          @ffs.set_activity_attribute(activity, @attribute, @value)
        end
      when :show
        activity.show
      when :sources
        activity.sources
      when :summary
        activity.summary
      else
        Log.fatal("Unknown activity command #{command}")
      end
    end

    def read_fit_file(fit_file)
      return Fit4Ruby::read(fit_file, @filter)
    end

    def change_unit_system(args)
      if args.length != 1 || !%w( metric statute ).include?(args[0])
        Log.error("You must specify 'metric' or 'statute' as unit system.")
      end

      if @db['config']['unit_system'].to_s != args[0]
        @db['config']['unit_system'] = args[0].to_sym
        @ffs.change_unit_system
      end
    end

    def change_html_dir(args)
      if args.length != 1
        Log.error('You must specify a directory')
      end

      if @db['config']['html_dir'] != args[0]
        @db['config']['html_dir'] =  args[0]
        @ffs.create_directories
        @ffs.generate_all_html_reports
      end
    end

    def update_gps_data
      epo_dir = File.join(@db_dir, 'epo')
      create_directory(epo_dir, 'GPS Data Cache')
      epo_file = File.join(epo_dir, 'EPO.BIN')

      if !File.exists?(epo_file) ||
         (File.mtime(epo_file) < Time.now - (6 * 60 * 60))
        # The EPO file only changes every 6 hours. No need to download it more
        # frequently if it already exists.
        if EPO_Downloader.new.download(epo_file)
          unless (remotesw_dir = @db['config']['import_dir'])
            Log.error "No device directory set. Please import an activity " +
                      "from your device first."
            return
          end
          remotesw_dir = File.join(remotesw_dir, '..', 'REMOTESW')
          unless Dir.exists?(remotesw_dir)
            Log.error "Cannot find '#{remotesw_dir}'. Please connect and " +
                      "mount your Garmin device."
            return
          end
          begin
            FileUtils.cp(epo_file, remotesw_dir)
          rescue
            Log.error "Cannot copy EPO.BIN file to your device at " +
                      "'#{remotesw_dir}'."
            return
          end
        end
      end
    end

    def day_in_localtime(args, format)
      begin
        (args.empty? ? Time.now : Time.parse(args[0])).
          localtime.strftime(format)
      rescue ArgumentError
        Log.abort("#{args[0]} is not a valid date. Use YYYY-MM-DD format.")
      end
    end

    def handle_version_update
      if @db['config']['version'] != VERSION
        Log.warn "PostRunner version upgrade detected."
        @ffs.handle_version_update
        @db['config']['version'] = VERSION
        Log.info "Version upgrade completed."
      end
    end

    # Earlier versions of PostRunner used a YAML file to store the activity
    # data. This method transfers the data from the old storage to the new
    # FitFileStore based database.
    def import_legacy_archive
      old_fit_dir = File.join(@db_dir, 'old_fit_dir')
      create_directory(old_fit_dir, 'Old Fit')

      cfg = RuntimeConfig.new(@db_dir)
      activities = ActivitiesDB.new(@db_dir, cfg).activities
      # Ensure that activities are sorted from earliest to last to properly
      # recognize the personal records during import.
      activities.sort! { |a1, a2| a1.timestamp <=> a2.timestamp }
      activities.each do |activity|
        file_name = File.join(@db_dir, 'fit', activity.fit_file)
        next unless File.exists?(file_name)

        Log.info "Converting #{activity.fit_file} to new DB format"
        @db.transaction do
          unless (new_activity = @ffs.add_fit_file(file_name))
            Log.warn "Cannot convert #{file_name} to new database format"
            next
          end
          new_activity.sport = activity.sport
          new_activity.sub_sport = activity.sub_sport
          new_activity.name = activity.name
          new_activity.norecord = activity.norecord
          FileUtils.move(file_name, File.join(old_fit_dir, activity.fit_file))
        end
      end
    end

  end

end

