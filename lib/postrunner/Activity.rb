require 'fit4ruby'

module PostRunner

  class Activity

    attr_reader :fit_file, :start_time

    def initialize(fit_file, fit_activity)
      @fit_file = fit_file
      @start_time = fit_activity.start_time
    end

  end

end

