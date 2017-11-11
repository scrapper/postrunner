#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = HRV_Analyzer.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015, 2016, 2017 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/FFS_Activity'

module PostRunner

  # This class analyzes the heart rate variablity based on the R-R intervals
  # in the given FIT file. It can compute RMSSD and a HRV score if the data
  # quality is good enough.
  class HRV_Analyzer

    attr_reader :hrv, :timestamps, :duration, :errors

    # According to Nunan et. al. 2010
    # (http://www.qeeg.co.uk/HRV/NUNAN-2010-A%20Quantitative%20Systematic%20Review%20of%20Normal%20Values%20for.pdf)
    # rMSSD (ms) are expected to be in the rage of 19 to 75 in healthy, adult
    # humans.  Typical ln(rMSSD) (ms) values for healthy, adult humans are
    # between 2.94 and 4.32. We use a slighly broader interval. We'll add a
    # bit of padding for our limits here.
    LN_RMSSD_MIN = 2.9
    LN_RMSSD_MAX = 4.4

    # Create a new HRV_Analyzer object.
    # @param arg [Activity, Array<Float>] R-R (or NN) time delta in seconds.
    def initialize(arg)
      if arg.is_a?(Array)
        rr_intervals = arg
      else
        activity = arg
        # Gather the RR interval list from the activity. Note that HRV data
        # still gets recorded after the activity has been stoped until the
        # activity gets saved.
        # Each Fit4Ruby::HRV object has an Array called 'time' that contains up
        # to 5 R-R interval durations. If less than 5 values are present the
        # remaining are filled with nil entries.
        rr_intervals = activity.fit_activity.hrv.map do |hrv|
          hrv.time.compact
        end.flatten
      end
      #$stderr.puts rr_intervals.inspect

      cleanup_rr_intervals(rr_intervals)
    end

    # The method can be used to check if we have valid HRV data. The FIT file
    # must have HRV data and the measurement duration must be at least 30
    # seconds.
    def has_hrv_data?
      @hrv && !@hrv.empty? && total_duration > 30.0
    end

    def data_quality
      (@hrv.size - @errors).to_f / @hrv.size * 100.0
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

      sum = 0.0
      cnt = 0
      @hrv[start_idx..end_idx].each do |i|
        if i
          # Input values are in seconds, but rmssd is usually computed from
          # milisecond values.
          sum += (i * 1000) ** 2.0
          cnt += 1
        end
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

    private

    def cleanup_rr_intervals(rr_intervals)
      # The timestamps Array stores the relative (to start of sequence) time
      # for each interval in the rr_intervals Array.
      @timestamps = []

      return if rr_intervals.empty?

      # The timer accumulates the interval durations and keeps track of the
      # timestamp of the current value with respect to the beging of the
      # series.
      timer = 0.0
      clean_rr_intervals = []
      @errors = 0
      rr_intervals.each_with_index do |rr, i|
        @timestamps << timer

        # The biggest source of errors are missed beats resulting in intervals
        # that are twice or more as large as the regular intervals. We look at
        # a window of values surrounding the current interval to determine
        # what's normal. We assume that at least half the values are normal.
        # When we sort the values by size, the middle value must be a good
        # proxy for a normal value.
        # Any values that are 1.8 times larger than the normal proxy value
        # will be discarded and replaced by nil.
        if rr > 1.8 * median_value(rr_intervals, i, 21)
          clean_rr_intervals << nil
          @errors += 1
        else
          clean_rr_intervals << rr
        end

        timer += rr
      end

      # This array holds the cleanedup heart rate variability values.
      @hrv = []
      0.upto(clean_rr_intervals.length - 2) do |i|
        rr1 = clean_rr_intervals[i]
        rr2 = clean_rr_intervals[i + 1]
        if rr1.nil? || rr2.nil?
          @hrv << nil
        else
          @hrv << (rr1 - rr2).abs
        end
      end

      # Save the overall duration of the HRV samples.
      @duration = timer
    end

    def median_value(ary, index, half_window_size)
      low_i = index - half_window_size
      low_i = 0 if low_i < 0
      high_i = index + half_window_size
      high_i = ary.length - 1 if high_i > ary.length - 1
      values = ary[low_i..high_i].delete_if{ |v| v.nil? }.sort

      median = values[values.length / 2]
    end

  end

end

