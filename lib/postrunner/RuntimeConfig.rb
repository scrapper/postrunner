module PostRunner

  class RuntimeConfig

    def initialize
      @settings = {}
      @settings['data_dir'] = File.join(ENV['HOME'], '.postrunner')
      @settings['fit_dir'] = File.join(@settings['data_dir'], 'fit')
    end

    def [](key)
      @settings[key]
    end

  end

  Config = RuntimeConfig.new

end

