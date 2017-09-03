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

    attr_reader :rr_intervals, :timestamps, :errors

    # According to Nunan et. al. 2010
    # (http://www.qeeg.co.uk/HRV/NUNAN-2010-A%20Quantitative%20Systematic%20Review%20of%20Normal%20Values%20for.pdf)
    # rMSSD (ms) are expected to be in the rage of 19 to 75 in healthy, adult
    # humans.  Typical ln(rMSSD) (ms) values for healthy, adult humans are
    # between 2.94 and 4.32. We use a slighly broader interval. We'll add a
    # bit of padding for our limits here.
    LN_RMSSD_MIN = 2.9
    LN_RMSSD_MAX = 4.4

    # Create a new HRV_Analyzer object.
    # @param rr_intervals [Array of Float] R-R (or NN) time delta in seconds.
    def initialize(rr_intervals)
      @errors = 0
      cleanup_rr_intervals(rr_intervals)
    end

    # The method can be used to check if we have valid HRV data. The FIT file
    # must have HRV data and the measurement duration must be at least 30
    # seconds.
    def has_hrv_data?
      !@rr_intervals.empty? && total_duration > 30.0
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
          # Input values are in seconds, but rmssd is usually computed from
          # milisecond values.
          sum += ((last_i - i) * 1000) ** 2.0
          cnt += 1
        end
        last_i = i
      end

      Math.sqrt(sum / cnt)
    end

    # The natural logarithm of rMSSD.
    # @param start_time [Float] Determines at what time mark (in seconds) the
    #        computation should start.
    # @param duration [Float] The duration of the total inteval in seconds to
    #        be considered for the computation. This value should be larger
    #        then 30 seconds to produce meaningful values.
    def ln_rmssd(start_time = 0.0, duration = nil)
      Math.log(rmssd(start_time, duration))
    end

    # The ln_rmssd values are hard to interpret. Since we know the expected
    # range we'll transform it into a value in the range 0 - 100. If the HRV
    # is measured early in the morning while standing upright and with a
    # regular 3s in/3s out breathing pattern the HRV Score is a performance
    # indicator. The higher it is, the better the performance condition.
    def hrv_score(start_time = 0.0, duration = nil)
      ssd = ln_rmssd(start_time, duration)
      ssd = LN_RMSSD_MIN if ssd < LN_RMSSD_MIN
      ssd = LN_RMSSD_MAX if ssd > LN_RMSSD_MAX

      (ssd - LN_RMSSD_MIN) * (100.0 / (LN_RMSSD_MAX - LN_RMSSD_MIN))
    end

    # This method tries to find a window of values that all lie within the
    # TP84 range and then calls the given block for that range.
    def one_sigma(calc_method)
      # Create a new Array that consists of rr_intervals and timestamps
      # tuples.
      set = []
      0.upto(@rr_intervals.length - 1) do |i|
        set << [ @rr_intervals[i] || 0.0, @timestamps[i] ]
      end

      percentiles = Percentiles.new(set)
      # Compile a list of all tuples with rr_intervals that are outside of the
      # PT84 (aka +1sigma range. Sort the list by time.
      not_1sigma = percentiles.not_tp_x(84.13).sort { |e1, e2| e1[1] <=> e2[1] }

      # Then find the largest window RR interval list so that all the values
      # in that window are within TP84.
      window_start = window_end = 0
      last = nil
      not_1sigma.each do |e|
        if last
          if (e[1] - last) > (window_end - window_start)
            window_start = last + 1
            window_end = e[1] - 1
          end
        end
        last = e[1]
      end

      # That window should be at least 30 seconds long. Otherwise we'll just use
      # all the values.
      if window_end - window_start < 30 || window_end < window_start
        return send(calc_method, 0.0, nil)
      end

      send(calc_method, window_start, window_end - window_start)
    end

    private

    def cleanup_rr_intervals(rr_intervals)
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
      return if rr_intervals.empty?

      window = [ rr_intervals.length / 4, 20 ].min
      intro_mean = rr_intervals[0..4 * window].reduce(:+) / (4 * window)
      predictor = LinearPredictor.new(window, intro_mean)

      # The timer accumulates the interval durations.
      timer = 0.0
      rr_intervals.each do |dt|
        timer += dt
        @timestamps << timer

        # Sometimes the hrv data is missing one or more beats. The next
        # detected beat is than listed with the time interval since the last
        # detected beat. We try to detect these skipped beats by looking for
        # time intervals that are 1.5 or more times larger than the predicted
        # value for this interval.
        if (next_dt = predictor.predict) && dt > 1.5 * next_dt
          @rr_intervals << nil
          @errors += 1
        else
          @rr_intervals << dt
          # Feed the value into the predictor.
          predictor.insert(dt)
        end
      end
    end

  end

end

