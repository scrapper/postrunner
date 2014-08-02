require 'fileutils'
require 'yaml'

require 'fit4ruby'
require 'postrunner/Activity'
require 'postrunner/PersonalRecords'
require 'postrunner/FlexiTable'

module PostRunner

  class ActivitiesDB

    include Fit4Ruby::Converters

    attr_reader :db_dir, :fit_dir

    def initialize(db_dir)
      @db_dir = db_dir
      @fit_dir = File.join(@db_dir, 'fit')
      @archive_file = File.join(@db_dir, 'archive.yml')

      create_directories
      begin
        if File.exists?(@archive_file)
          @activities = YAML.load_file(@archive_file)
        else
          @activities = []
        end
      rescue StandardError
        Log.fatal "Cannot load archive file '#{@archive_file}': #{$!}"
      end

      unless @activities.is_a?(Array)
        Log.fatal "The archive file '#{@archive_file}' is corrupted"
      end

      # The reference to this object is needed inside Activity object but is
      # not stored in the archive file. We have to retrofit the Activity
      # instances with this data.
      @activities.each do |a|
        a.db = self
      end

      @records = PersonalRecords.new(self)
    end

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

      sync
      Log.info "#{fit_file} successfully added to archive"

      true
    end

    def delete(activity)
      @activities.delete(activity)
      sync
    end

    def rename(activity, name)
      activity.rename(name)
      sync
    end

    def check
      @activities.each { |a| a.check }
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

    def list
      i = 0
      t = FlexiTable.new
      t.head
      t.row(%w( Ref. Activity Start Distance Duration Pace ),
            { :halign => :left })
      t.set_column_attributes([
        { :halign => :right },
        {}, {},
        { :halign => :right },
        { :halign => :right },
        { :halign => :right }
      ])
      t.body
      @activities.each do |a|
        t.row([
          i += 1,
          a.name[0..19],
          a.timestamp.strftime("%a, %Y %b %d %H:%M"),
          "%.2f" % (a.total_distance / 1000),
          secsToHMS(a.total_timer_time),
          speedToPace(a.avg_speed) ])
      end
      puts t.to_s
    end

    def show_records
      puts @records.to_s
    end

    private

    def sync
      begin
        File.open(@archive_file, 'w') { |f| f.write(@activities.to_yaml) }
      rescue StandardError
        Log.fatal "Cannot write archive file '#{@archive_file}': #{$!}"
      end

      @records.sync
    end

    def create_directories
      create_directory(@db_dir, 'data')
      create_directory(@fit_dir, 'fit')
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

  end

end

