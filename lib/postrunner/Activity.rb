require 'fit4ruby'

require 'postrunner/ActivityReport'
require 'postrunner/TrackView'
require 'postrunner/ChartView'

module PostRunner

  class Activity

    attr_reader :fit_file, :name, :fit_activity
    attr_accessor :db

    # This is a list of variables that provide data from the fit file. To
    # speed up access to it, we cache the data in the activity database.
    @@CachedVariables = %w( timestamp total_distance total_timer_time
                            avg_speed )

    def initialize(db, fit_file, fit_activity, name = nil)
      @db = db
      @fit_file = fit_file
      @fit_activity = fit_activity
      @name = name || fit_file

      @@CachedVariables.each do |v|
        v_str = "@#{v}"
        instance_variable_set(v_str, fit_activity.send(v))
        self.class.send(:attr_reader, v.to_sym)
      end
    end

    def check
      @fit_activity = load_fit_file
      Log.info "FIT file #{@fit_file} is OK"
    end

    def dump(filter)
      @fit_activity = load_fit_file(filter)
    end

    def yaml_initialize(tag, value)
      # Create attr_readers for cached variables.
      @@CachedVariables.each { |v| self.class.send(:attr_reader, v.to_sym) }

      # Load all attributes and assign them to instance variables.
      value.each do |a, v|
        instance_variable_set("@" + a, v)
      end
      # Use the FIT file name as activity name if none has been set yet.
      @name = @fit_file unless @name
    end

    def encode_with(coder)
      attr_ignore = %w( @db @fit_activity )

      instance_variables.each do |v|
        v = v.to_s
        next if attr_ignore.include?(v)

        coder[v[1..-1]] = instance_variable_get(v)
      end
    end

    def show
      @fit_activity = load_fit_file unless @fit_activity
      view = TrackView.new(self, '../../html')
      view.generate_html
      chart = ChartView.new(self, '../../html')
      chart.generate_html
    end

    def summary
      @fit_activity = load_fit_file unless @fit_activity
      puts ActivityReport.new(@fit_activity).to_s
    end

    def rename(name)
      @name = name
    end

    def register_records(db)
      @fit_activity.personal_records.each do |r|
        if r.longest_distance == 1
          # In case longest_distance is 1 the distance is stored in the
          # duration field in 10-th of meters.
          db.register_result(r.duration * 10.0 , 0, r.start_time, @fit_file)
        else
          db.register_result(r.distance, r.duration, r.start_time, @fit_file)
        end
      end
    end

    private

    def load_fit_file(filter = nil)
      fit_file = File.join(@db.fit_dir, @fit_file)
      begin
        return Fit4Ruby.read(fit_file, filter)
      rescue Fit4Ruby::Error
        Log.fatal $!
      end
    end

  end

end

