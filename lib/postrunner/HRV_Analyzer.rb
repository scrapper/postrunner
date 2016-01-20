#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = HRV_Analyzer.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/LinearPredictor'

module PostRunner

  # This class analyzes the heart rate variablity based on the R-R intervals
  # in the given FIT file. It can compute RMSSD and a HRV score if the data
  # quality is good enough.
  class HRV_Analyzer

    attr_reader :rr_intervals, :timestamps

    # Create a new HRV_Analyzer object.
    # @param fit_file [Fit4Ruby::Activity] FIT file to analyze.
    def initialize(fit_file)
      @fit_file = fit_file
      collect_rr_intervals
    end

    # The method can be used to check if we have valid HRV data. The FIT file
    # must have HRV data and the measurement duration must be at least 30
    # seconds.
    def has_hrv_data?
      !@fit_file.hrv.empty? && total_duration > 30.0
    end

    # Return the total duration of all measured intervals in seconds.
    def total_duration
      @timestamps[-1]
    end

    # Compute the root mean square of successive differences.
    # @param start_time [Float] Determines at what time mark (in seconds) the
    #        computation should start.
    # @param duration [Float] The duration of the total inteval in seconds to
    #        be considered for the computation. This value should be larger
    #        then 30 seconds to produce meaningful values.
    def rmssd(start_time = 0.0, duration = nil)
      # Find the start index based on the requested interval start time.
      start_idx = 0
      @timestamps.each do |ts|
        break if ts >= start_time
        start_idx += 1
      end
      # Find the end index based on the requested interval duration.
      if duration
        end_time = start_time + duration
        end_idx = start_idx
        while end_idx < (@timestamps.length - 1) &&
              @timestamps[end_idx] < end_time
          end_idx += 1
        end
      else
        end_idx = -1
      end

      last_i = nil
      sum = 0.0
      cnt = 0
      @rr_intervals[start_idx..end_idx].each do |i|
        if i && last_i
          sum += (last_i - i) ** 2.0
          cnt += 1
        end
        last_i = i
      end

      Math.sqrt(sum / cnt)
    end

    # The RMSSD value is not very easy to memorize. Alternatively, we can
    # multiply the natural logarithm of RMSSD by -20. This usually results in
    # values between 1.0 (for untrained) and 100.0 (for higly trained)
    # athletes. Values larger than 100.0 are rare but possible.
    # @param start_time [Float] Determines at what time mark (in seconds) the
    #        computation should start.
    # @param duration [Float] The duration of the total inteval in seconds to
    #        be considered for the computation. This value should be larger
    #        then 30 seconds to produce meaningful values.
    def lnrmssdx20(start_time = 0.0, duration = nil)
      -20.0 * Math.log(rmssd(start_time, duration))
    end

    # This method is similar to lnrmssdx20 but it tries to search the data for
    # the best time period to compute the lnrmssdx20 value from.
    def lnrmssdx20_1sigma
      # Create a new Array that consists of rr_intervals and timestamps
      # tuples.
      set = []
      0.upto(@rr_intervals.length - 1) do |i|
        set << [ @rr_intervals[i] ? @rr_intervals[i] : 0.0, @timestamps[i] ]
      end

      percentiles = Percentiles.new(set)
      # Compile a list of all tuples with rr_intervals that are outside of the
      # PT84 (aka +1sigma range. Sort the list by time.
      not_1sigma = percentiles.not_tp_x(84.13).sort { |e1, e2| e1[1] <=> e2[1] }

      # Then find the largest time gap in that list. So all the values in that
      # gap are within TP84.
      gap_start = gap_end = 0
      last = nil
      not_1sigma.each do |e|
        if last
          if (e[1] - last) > (gap_end - gap_start)
            gap_start = last
            gap_end = e[1]
          end
        end
        last = e[1]
      end
      # That gap should be at least 30 seconds long. Otherwise we'll just use
      # all the values.
      return lnrmssdx20 if gap_end - gap_start < 30

      lnrmssdx20(gap_start, gap_end - gap_start)
    end

    private

    def collect_rr_intervals
      # The rr_intervals Array stores the beat-to-beat time intervals (R-R).
      # If one or move beats have been skipped during measurement, a nil value
      # is inserted.
      @rr_intervals = []
      # The timestamps Array stores the relative (to start of sequence) time
      # for each interval in the rr_intervals Array.
      @timestamps = []

      # Each Fit4Ruby::HRV object has an Array called 'time' that contains up
      # to 5 R-R interval durations. If less than 5 are present, they are
      # filled with nil.
      raw_rr_intervals = []
      @fit_file.hrv.each do |hrv|
        raw_rr_intervals += hrv.time.compact
      end
      return if raw_rr_intervals.empty?

      window = 20
      intro_mean = raw_rr_intervals[0..4 * window].reduce(:+) / (4 * window)
      predictor = LinearPredictor.new(window, intro_mean)

      # The timer accumulates the interval durations.
      timer = 0.0
      raw_rr_intervals.each do |dt|
        timer += dt
        @timestamps << timer

        # Sometimes the hrv data is missing one or more beats. The next
        # detected beat is than listed with the time interval since the last
        # detected beat. We try to detect these skipped beats by looking for
        # time intervals that are 1.5 or more times larger than the predicted
        # value for this interval.
        if (next_dt = predictor.predict) && dt > 1.5 * next_dt
          @rr_intervals << nil
        else
          @rr_intervals << dt
          # Feed the value into the predictor.
          predictor.insert(dt)
        end
      end

      # The accumulated R-R intervals tend to be slightly larger than the
      # total timer time measured by the device. It's unclear why this is the
      # case, but I assume it's an accumulated measuring error. We calculate a
      # correction factor and time-warp all timestamps so the total time
      # aligns with the other data of the FIT file. We also correct the R-R
      # intervals times accordingly.
      time_warp_factor = @fit_file.total_timer_time / @timestamps.last
      @timestamps.map! { |t| t * time_warp_factor }
      @rr_intervals.map! { |t| t ? t * time_warp_factor : nil }
    end

  end

end

