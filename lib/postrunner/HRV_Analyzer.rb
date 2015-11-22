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

module PostRunner

  # This class analyzes the heart rate variablity based on the R-R intervals
  # in the given FIT file. It can compute RMSSD and a HRV score if the data
  # quality is good enough.
  class HRV_Analyzer

    def initialize(fit_file)
      @fit_file = fit_file
      collect_rr_intervals
    end

    # The method can be used to check if we have valid HRV data. The FIT file
    # must have HRV data, it must have correctly measured 90% of the beats and
    # the measurement duration must be at least 30 seconds.
    def has_hrv_data?
      !@fit_file.hrv.empty? &&
        @missed_beats < (0.1 * @rr_intervals.length) &&
        total_duration > 30.0
    end

    # Return the total duration of all measured intervals in seconds.
    def total_duration
      @rr_intervals.inject(:+)
    end

    # root mean square of successive differences
    def rmssd
      last_i = nil
      sum = 0.0
      @rr_intervals.each do |i|
        if last_i
          sum += (last_i - i) ** 2.0
        end
        last_i = i
      end
      Math.sqrt(sum / (@rr_intervals.length - 1))
    end

    # The RMSSD value is not very easy to memorize. Alternatively, we can
    # multiply the natural logarithm of RMSSD by -20. This usually results in
    # values between 40 (for untrained) and 100 (for higly trained) athletes.
    def lnrmssdx20
      (-20.0 * Math.log(rmssd)).round.to_i
    end

    private

    def collect_rr_intervals
      raw_rr_intervals = []
      @fit_file.hrv.each do |hrv|
        raw_rr_intervals += hrv.time.compact
      end

      prev_dts = []
      avg_dt = nil
      @missed_beats = 0
      @rr_intervals = []
      raw_rr_intervals.each do |dt|
        # Sometimes the hrv data is missing one or more beats. The next
        # detected beat is then listed with a time interval since the last
        # detected beat. We try to detect these skipped beats by looking for
        # time intervals that are 1.8 or more times larger than the average of
        # the last 5 good intervals.
        if avg_dt && dt > 1.8 * avg_dt
          # If we have found skipped beats we calcluate how many beats were
          # skipped.
          skip = (dt / avg_dt).round.to_i
          # We count the total number of skipped beats. We don't use the HRV
          # data if too many beats were skipped.
          @missed_beats += skip
          # Insert skip times the average skipped beat intervals.
          skip.times do
            new_dt = dt / skip
            @rr_intervals << new_dt
            prev_dts << new_dt
            prev_dts.shift if prev_dts.length > 5
          end
        else
          @rr_intervals << dt
          # We keep a list of the previous 5 good intervals and compute the
          # average value of them.
          prev_dts << dt
          prev_dts.shift if prev_dts.length > 5
        end
        avg_dt = prev_dts.inject(:+) / prev_dts.length
      end
    end

  end

end

