#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Main.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'optparse'
require 'logger'
require 'fit4ruby'

require 'postrunner/version'
require 'postrunner/RuntimeConfig'
require 'postrunner/ActivitiesDB'

module PostRunner

  # Use the Logger provided by Fit4Ruby for all console output.
  Log = Fit4Ruby::ILogger.new(STDOUT)
  Log.formatter = proc { |severity, datetime, progname, msg|
    "#{severity == Logger::INFO ? '' : "#{severity}:"} #{msg}\n"
  }
  Log.level = Logger::INFO

  class Main

    def initialize(args)
      @filter = nil
      @name = nil
      @activities = nil
      @db_dir = File.join(ENV['HOME'], '.postrunner')

      return if (args = parse_options(args)).nil?

      @cfg = RuntimeConfig.new(@db_dir)
      execute_command(args)
    end

    private

    def parse_options(args)
      parser = OptionParser.new do |opts|
        opts.banner = "Usage postrunner <command> [options]"

        opts.separator <<"EOT"

Copyright (c) 2014 by Chris Schlaeger

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

        opts.separator ""
        opts.separator "Options for the 'import' and 'rename' command:"
        opts.on('--name name', String,
                'Name or rename the activity to the specified name') do |n|
          @name = n
        end

        opts.separator ""
        opts.separator "General options:"
        opts.on('--dbdir dir', String,
                'Directory for the activity database and related files') do |d|
          @db_dir = d
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
          $stderr.puts VERSION
          return nil
        end

        opts.separator <<"EOT"

Commands:

check [ <fit file> | <ref> ... ]
          Check the provided FIT file(s) for structural errors. If no file or
          reference is provided, the complete archive is checked.

dump <fit file> | <ref>
          Dump the content of the FIT file.

import [ <fit file> | <directory> ]
          Import the provided FIT file(s) into the postrunner database. If no
          file or directory is provided, the directory that was used for the
          previous import is being used.

delete <ref>
          Delete the activity from the archive.

list
          List all FIT files stored in the data base.

records
          List all personal records.

rename <ref>
          Replace the FIT file name with a more meaningful name that describes
          the activity.

show [ <ref> ]
          Show the referenced FIT activity in a web browser. If no reference
          is provided show the list of activities in the database.

summary <ref>
          Display the summary information for the FIT file.

units   metric | statute
          Change the unit system.


<fit file> An absolute or relative name of a .FIT file.

<ref>      The index or a range of indexes to activities in the database.
           :1 is the newest imported activity
           :-1 is the oldest imported activity
           :1-2 refers to the first and second activity in the database
EOT

      end

      parser.parse!(args)
    end

    def execute_command(args)
      @activities = ActivitiesDB.new(@db_dir, @cfg)

      case (cmd = args.shift)
      when 'check'
        if args.empty?
          @activities.check
        else
          process_files_or_activities(args, :check)
        end
      when 'delete'
        process_activities(args, :delete)
      when 'dump'
        @filter = Fit4Ruby::FitFilter.new unless @filter
        process_files_or_activities(args, :dump)
      when 'import'
        if args.empty?
          # If we have no file or directory for the import command, we get the
          # most recently used directory from the runtime config.
          process_files([ @cfg.get_option(:import_dir) ], :import)
        else
          process_files(args, :import)
          if args.length == 1 && Dir.exists?(args[0])
            # If only one directory was specified as argument we store the
            # directory for future use.
            @cfg.set_option(:import_dir, args[0])
          end
        end
      when 'list'
        @activities.list
      when 'records'
        @activities.show_records
      when 'rename'
        process_activities(args, :rename)
      when 'show'
        if args.empty?
          @activities.show_list_in_browser
        else
          process_activities(args, :show)
        end
      when 'summary'
        process_activities(args, :summary)
      when 'units'
        change_unit_system(args)
      when nil
        Log.fatal("No command provided. " +
                  "See 'postrunner -h' for more information.")
      else
        Log.fatal("Unknown command '#{cmd}'. " +
                  "See 'postrunner -h' for more information.")
      end
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
        Log.fatal("You must provide at least one activity reference.")
      end

      activity_refs.each do |a_ref|
        if a_ref[0] == ':'
          activities = @activities.find(a_ref[1..-1])
          if activities.empty?
            Log.warn "No matching activities found for '#{a_ref}'"
            return
          end
          activities.each { |a| process_activity(a, command) }
        else
          Log.fatal "Activity references must start with ':': #{a_ref}"
        end
      end
    end

    def process_files(files_or_dirs, command)
      if files_or_dirs.empty?
        Log.fatal("You must provide at least one .FIT file name.")
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

    def process_file(file, command)
      case command
      when :check, :dump
        read_fit_file(file)
      when :import
        @activities.add(file)
      else
        Log.fatal("Unknown file command #{command}")
      end
    end

    def process_activity(activity, command)
      case command
      when :check
        activity.check
      when :delete
        @activities.delete(activity)
      when :dump
        activity.dump(@filter)
      when :rename
        @activities.rename(activity, @name)
      when :show
        activity.show
      when :summary
        activity.summary
      else
        Log.fatal("Unknown activity command #{command}")
      end
    end

    def read_fit_file(fit_file)
      begin
        return Fit4Ruby::read(fit_file, @filter)
      rescue StandardError
        Log.error("Cannot read FIT file '#{fit_file}': #{$!}")
      end
    end

    def change_unit_system(args)
      if args.length != 1 || !%w( metric statute ).include?(args[0])
        Log.fatal("You must specify 'metric' or 'statute' as unit system.")
      end

      if @cfg[:unit_system].to_s != args[0]
        @cfg.set_option(:unit_system, args[0].to_sym)
        @activities.generate_all_html_reports
      end
    end

  end

end

