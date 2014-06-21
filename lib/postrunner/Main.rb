require 'optparse'
require 'logger'
require 'fit4ruby'
require 'postrunner/ActivitiesDB'

module PostRunner

  Log = Fit4Ruby::ILogger.new(STDOUT)

  class Main

    def initialize(args)
      @filter = nil
      @activities = ActivitiesDB.new(File.join(ENV['HOME'], '.postrunner'))

      execute_command(parse_options(args))
    end

    private

    def parse_options(args)
      parser = OptionParser.new do |opts|
        opts.banner = "Usage postrunner <command> [options]"
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
      end

      parser.parse!(args)
    end

    def execute_command(args)
      case args.shift
      when 'check'
        process_files(args, :check)
      when 'dump'
        @filter = Fit4Ruby::FitFilter.new unless @filter
        process_files_or_activities(args, :dump)
      when 'import'
        process_files(args, :import)
      when 'list'
        @activities.list
      when 'summary'
        process_files(args, :summary)
      else
        Log.fatal("No command provided")
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
          process_files(foa, command)
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
      if command == :import
        @activities.add(file)
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

