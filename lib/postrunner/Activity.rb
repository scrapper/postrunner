require 'fit4ruby'

module PostRunner

  class Activity

    attr_reader :fit_file, :name

    # This is a list of variables that provide data from the fit file. To
    # speed up access to it, we cache the data in the activity database.
    @@CachedVariables = %w( start_time distance duration avg_speed )

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
      load_fit_file
      Log.info "FIT file #{@fit_file} is OK"
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
      attr_ignore = %w( @fit_activity )

      instance_variables.each do |v|
        v = v.to_s
        next if attr_ignore.include?(v)

        coder[v[1..-1]] = instance_variable_get(v)
      end
    end

    #def method_missing(method_name, *args, &block)
    #  @fit_activity = load_fit_file unless @fit_activity
    #  @fit_activity.send(method_name, *args, &block)
    #end

    def summary(fit_file)
      load_fit_file

    end

    def rename(name)
      @name = name
    end

    private

    def load_fit_file
      fit_file = File.join(@db.fit_dir, @fit_file)
      begin
        return Fit4Ruby.read(fit_file)
      rescue Fit4Ruby::Error
        Log.fatal $!
      end
    end

  end

end

