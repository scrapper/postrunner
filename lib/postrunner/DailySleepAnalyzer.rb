#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DailySleepAnalzyer.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

module PostRunner

  # This class extracts the sleep information from a set of monitoring files
  # and determines when and how long the user was awake or had a light or deep
  # sleep.
  class DailySleepAnalyzer

    # Utility class to store the interval of a sleep/wake phase.
    class SleepInterval < Struct.new(:from_time, :to_time, :phase)
    end

    attr_reader :sleep_intervals, :utc_offset,
                :total_sleep, :deep_sleep, :light_sleep

    # Create a new DailySleepAnalyzer object to analyze the given monitoring
    # files.
    # @param monitoring_files [Array] A set of Monitoring_B objects
    # @param day [String] Day to analyze as YY-MM-DD string
    def initialize(monitoring_files, day)
      @noon_yesterday = @noon_today = @utc_offset = nil
      @sleep_intervals = []

      # Day as Time object. Midnight UTC.
      day_as_time = Time.parse(day + "-00:00:00+00:00").gmtime
      extract_data_from_monitor_files(monitoring_files, day_as_time)
      fill_sleep_activity
      smoothen_sleep_activity
      analyze
      trim_wake_periods_at_ends
      calculate_totals
    end

    private

    def extract_utc_offset(monitoring_file)
      # The monitoring files have a monitoring_info section that contains a
      # timestamp in UTC and a local_time field for the same time in the local
      # time. If any of that isn't present, we use an offset of 0.
      if (mi = monitoring_file.monitoring_infos).nil? || mi.empty? ||
         (localtime = mi[0].local_time).nil?
        return 0
      end

      # Otherwise the delta in seconds between UTC and localtime is the
      # offset.
      localtime - mi[0].timestamp
    end

    def extract_data_from_monitor_files(monitoring_files, day)
      # We use an Array with entries for every minute from noon yesterday to
      # noon today.
      @sleep_activity = Array.new(24 * 60, nil)
      monitoring_files.each do |mf|
        utc_offset = extract_utc_offset(mf)
        # Noon (local time) the day before the requested day. The time object
        # is UTC for the noon time in the local time zone.
        noon_yesterday = day - 12 * 60 * 60 - utc_offset
        # Noon (local time) of the current day
        noon_today = day + 12 * 60 * 60 - utc_offset

        mf.monitorings.each do |m|
          # Ignore all entries outside our 24 hour window from noon the day
          # before to noon the current day.
          next if m.timestamp < noon_yesterday || m.timestamp >= noon_today

          if @noon_yesterday.nil? && @noon_today.nil?
            # The instance variables will only be set once we have found our
            # first monitoring file that matches the requested day. We use the
            # local time setting for this first file even if it changes in
            # subsequent files.
            @noon_yesterday = noon_yesterday
            @noon_today = noon_today
            @utc_offset = utc_offset
          end

          if (cati = m.current_activity_type_intensity)
            activity_type = cati & 0x1F

            # Compute the index in the @sleep_activity Array.
            index = (m.timestamp - @noon_yesterday) / 60
            if activity_type == 8
              intensity = (cati >> 5) & 0x7
              @sleep_activity[index] = intensity
            else
              @sleep_activity[index] = false
            end
          end
        end
      end

    end

    def fill_sleep_activity
      current = nil
      @sleep_activity = @sleep_activity.reverse.map do |v|
        v.nil? ? current : current = v
      end.reverse

      if $DEBUG
        File.open('sleep-data.csv', 'w') do |f|
          f.puts 'Date;Value'
          @sleep_activity.each_with_index do |v, i|
            f.puts "#{@noon_yesterday + i * 60};#{v.is_a?(Fixnum) ? v : 8}"
          end
        end
      end
    end

    def smoothen_sleep_activity
      window_size = 30

      @smoothed_sleep_activity = Array.new(24 * 60, nil)
      0.upto(24 * 60 - 1).each do |i|
        window_start_idx = i - window_size
        window_end_idx = i
        sum = 0.0
        (i - window_size + 1).upto(i).each do |j|
          sum += j < 0 ? 8.0 :
                 @sleep_activity[j].is_a?(Fixnum) ? @sleep_activity[j] : 8
        end
        @smoothed_sleep_activity[i] = sum / window_size
      end

      if $DEBUG
        File.open('smoothed-sleep-data.csv', 'w') do |f|
          f.puts 'Date;Value'
          @smoothed_sleep_activity.each_with_index do |v, i|
            f.puts "#{@noon_yesterday + i * 60};#{v}"
          end
        end
      end
    end

    def analyze
      current_phase = :awake
      current_phase_start = @noon_yesterday
      @sleep_intervals = []

      @smoothed_sleep_activity.each_with_index do |v, idx|
        if v < 0.25
          phase = :deep_sleep
        elsif v < 1.5
          phase = :light_sleep
        else
          phase = :awake
        end

        if current_phase != phase
          t = @noon_yesterday + 60 * idx
          @sleep_intervals << SleepInterval.new(current_phase_start, t,
                                                current_phase)
          current_phase = phase
          current_phase_start = t
        end
      end
      @sleep_intervals << SleepInterval.new(current_phase_start, @noon_today,
                                            current_phase)
    end

    def trim_wake_periods_at_ends
      first_deep_sleep_idx = last_deep_sleep_idx = nil

      @sleep_intervals.each_with_index do |p, idx|
        if p.phase == :deep_sleep ||
           (p.phase == :light_sleep && ((p.to_time - p.from_time) > 15 * 60))
          first_deep_sleep_idx = idx unless first_deep_sleep_idx
          last_deep_sleep_idx = idx
        end
      end

      return unless first_deep_sleep_idx && last_deep_sleep_idx

      if first_deep_sleep_idx > 0 &&
         @sleep_intervals[first_deep_sleep_idx - 1].phase == :light_sleep
         first_deep_sleep_idx -= 1
      end
      if last_deep_sleep_idx < @sleep_intervals.length - 2 &&
         @sleep_intervals[last_deep_sleep_idx + 1].phase == :light_sleep
        last_deep_sleep_idx += 1
      end

      @sleep_intervals =
        @sleep_intervals[first_deep_sleep_idx..last_deep_sleep_idx]
    end

    def calculate_totals
      @total_sleep = @light_sleep = @deep_sleep = 0
      @sleep_intervals.each do |p|
        if p.phase != :awake
          seconds = p.to_time - p.from_time
          @total_sleep += seconds
          if p.phase == :light_sleep
            @light_sleep += seconds
          else
            @deep_sleep += seconds
          end
        end
      end
    end

    # Return the begining of the current day in local time as Time object.
    def begining_of_today(time = Time.now)
      sec, min, hour, day, month, year = time.to_a
      sec = min = hour = 0
      Time.new(*[ year, month, day, hour, min, sec, 0 ]).localtime
    end

  end

end

