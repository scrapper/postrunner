require 'fileutils'
require 'yaml'

require 'fit4ruby'
require 'postrunner/Activity'

module PostRunner

  class ActivitiesDB

    def initialize(db_dir)
      @db_dir = db_dir
      @fit_dir = File.join(@db_dir, 'fit')
      @archive_file = File.join(@db_dir, 'archive.yml')

      if Dir.exists?(@db_dir)
        begin
          if File.exists?(@archive_file)
            @activities = YAML.load_file(@archive_file)
          else
            @activities = []
          end
        rescue
          Log.fatal "Cannot load archive file #{@archive_file}: #{$!}"
        end
      else
        create_directories
        @activities = []
      end
    end

    def add(fit_file)
      base_fit_file = File.basename(fit_file)
      if @activities.find { |a| a.fit_file == base_fit_file }
        Log.warn "Activity #{fit_file} is already included in the archive"
        return false
      end

      begin
        fit_activity = Fit4Ruby.read(fit_file)
      rescue
        Log.error "Cannot read #{fit_file}: #{$!}"
        return false
      end

      begin
        FileUtils.cp(fit_file, @fit_dir)
      rescue
        Log.fatal "Cannot copy #{fit_file} into #{@fit_dir}: #{$!}"
      end

      @activities << Activity.new(base_fit_file, fit_activity)
      sync
      Log.info "#{fit_file} successfully added to archive"

      true
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
        puts "iv: #{sidx} - #{eidx}"
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

    def list
      i = 0
      @activities.each do |a|
        i += 1
        puts "#{"%4d" % i} #{"%12s" % a.fit_file} #{a.start_time}"
      end
    end

    private

    def sync
      File.open(@archive_file, 'w') { |f| f.write(@activities.to_yaml) }
    end

    def create_directories
      Log.info "Creating data directory #{@db_dir}"
      begin
        Dir.mkdir(@db_dir)
      rescue
        Log.fatal "Cannot create data directory #{@db_dir}: #{$!}"
      end
      begin
        Dir.mkdir(@fit_dir)
      rescue
        Log.fatal "Cannot create fit directory #{@fit_dir}: #{$!}"
      end
    end

  end

end

