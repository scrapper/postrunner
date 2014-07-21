require 'optparse'
require 'logger'
require 'fit4ruby'
require 'postrunner/RuntimeConfig'
require 'postrunner/ActivitiesDB'

module PostRunner

  # Use the Logger provided by Fit4Ruby for all console output.
  Log = Fit4Ruby::ILogger.new(STDOUT)
  Log.formatter = proc { |severity, datetime, progname, msg|
    "#{severity == Logger::INFO ? '' : "#{severity}:"} #{msg}\n"
  }

  class Main

    def initialize(args)
      @filter = nil
      @name = nil
      @activities = ActivitiesDB.new(File.join(ENV['HOME'], '.postrunner'))

      execute_command(parse_options(args))
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
        opts.on('-v', '--verbose',
                'Show internal messages helpful for debugging problems') do
          Log.level = Logger::DEBUG
        end
        opts.on('-h', '--help', 'Show this message') do
          $stderr.puts opts
          exit
        end
        opts.on('--version', 'Show version number') do
          $stderr.puts VERSION
          exit
        end

        opts.separator <<"EOT"

Commands:

check <fit file> ...
          Check the provided FIT file(s) for structural errors.

dump <fit file> | <ref>
          Dump the content of the FIT file.

import <fit file> | <directory>
          Import the provided FIT file(s) into the postrunner database.

list
          List all FIT files stored in the data base.

rename <ref>
          Replace the FIT file name with a more meaningful name that describes
          the activity.

summary <fit file> | <ref>
          Display the summary information for the FIT file.
EOT

      end

      parser.parse!(args)
    end

    def execute_command(args)
      case (cmd = args.shift)
      when 'check'
        process_files_or_activities(args, :check)
      when 'dump'
        @filter = Fit4Ruby::FitFilter.new unless @filter
        process_files_or_activities(args, :dump)
      when 'import'
        process_files(args, :import)
      when 'list'
        @activities.list
      when 'rename'
        process_activities(args, :rename)
      when 'summary'
        process_files_or_activities(args, :summary)
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
          files = @activities.map_to_files(foa[1..-1])
          if files.empty?
            Log.warn "No matching activities found for '#{foa}'"
            return
          end

          process_files(files, command)
        else
          process_files([ foa ], command)
        end
      end
    end

    def process_activities(activity_files, command)
      activity_files.each do |a|
        if a[0] == ':'
          files = @activities.map_to_files(a[1..-1])
          if files.empty?
            Log.warn "No matching activities found for '#{a}'"
            return
          end
          process_files(files, command)
        else
          Log.fatal "Activity references must start with ':': #{a}"
        end
      end

    end

    def process_files(files_or_dirs, command)
      if files_or_dirs.empty?
        Log.fatal("You must provide at least one .FIT file name")
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
      when :import
        @activities.add(file)
      when :rename
        @activities.rename(file, @name)
      else
        begin
          activity = Fit4Ruby::read(file, @filter)
          #rescue
          #  Log.error("File '#{file}' is corrupted!: #{$!}")
        end
        puts activity.to_s if command == :summary
      end
    end

  end

end

