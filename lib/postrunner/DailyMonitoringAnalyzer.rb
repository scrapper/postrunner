#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DailyMonitoringAnalzyer.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

module PostRunner

  class DailyMonitoringAnalyzer

    attr_reader :window_start_time, :window_end_time

    class MonitoringSample

      attr_reader :timestamp, :activity_type, :cycles, :steps,
                  :floors_climbed, :floors_descended, :distance,
                  :active_calories, :weekly_moderate_activity_minutes,
                  :weekly_vigorous_activity_minutes

      def initialize(m)
        @timestamp = m.timestamp
        types = [
          'generic', 'running', 'cycling', 'transition',
          'fitness_equipment', 'swimming', 'walking', 'unknown7',
          'resting', 'unknown9'
        ]
        if (cati = m.current_activity_type_intensity)
          @activity_type = types[cati & 0x1F]
          @activity_intensity = (cati >> 5) & 0x7
        else
          @activity_type = m.activity_type
        end
        @active_time = m.active_time
        @active_calories = m.active_calories
        @ascent = m.ascent
        @descent = m.descent
        @floors_climbed = m.floors_climbed
        @floors_descended = m.floors_descended
        @cycles = m.cycles
        @distance = m.distance
        @duration_min = m.duration_min
        @heart_rate = m.heart_rate
        @steps = m.steps
        @weekly_moderate_activity_minutes = m.weekly_moderate_activity_minutes
        @weekly_vigorous_activity_minutes = m.weekly_vigorous_activity_minutes
      end

    end

    def initialize(monitoring_files, day)
      # Day as Time object. Midnight UTC.
      day_as_time = Time.parse(day + "-00:00:00+00:00").gmtime

      @samples = []
      extract_data_from_monitor_files(monitoring_files, day_as_time)

      # We must have information about the local time zone the data was
      # recorded in. Abort if not available.
      return unless @utc_offset
    end

    def total_distance
      distance = 0.0
      @samples.each do |s|
        if s.distance && s.distance > distance
          distance = s.distance
        end
      end

      distance
    end

    def total_floors
      floors_climbed = floors_descended = 0.0

      @samples.each do |s|
        if s.floors_climbed && s.floors_climbed > floors_climbed
          floors_climbed = s.floors_climbed
        end
        if s.floors_descended && s.floors_descended > floors_descended
          floors_descended = s.floors_descended
        end
      end

      { :floors_climbed => (floors_climbed / 3.048).floor,
        :floors_descended => (floors_descended / 3.048).floor }
    end

    def steps_distance_calories
      total_cycles = Hash.new(0.0)
      total_distance = Hash.new(0.0)
      total_calories = Hash.new(0.0)

      @samples.each do |s|
        at = s.activity_type
        if s.cycles && s.cycles > total_cycles[at]
          total_cycles[at] = s.cycles
        end
        if s.distance && s.distance > total_distance[at]
          total_distance[at] = s.distance
        end
        if s.active_calories && s.active_calories > total_calories[at]
          total_calories[at] = s.active_calories
        end
      end

      distance = calories = 0.0
      if @monitoring_info
        if @monitoring_info.activity_type &&
           @monitoring_info.cycles_to_distance &&
           @monitoring_info.cycles_to_calories
          walking_cycles_to_distance = running_cycles_to_distance = nil
          walking_cycles_to_calories = running_cycles_to_calories = nil

          @monitoring_info.activity_type.each_with_index do |at, idx|
            if at == 'walking'
              walking_cycles_to_distance =
                @monitoring_info.cycles_to_distance[idx]
              walking_cycles_to_calories =
                @monitoring_info.cycles_to_calories[idx]
            elsif at == 'running'
              running_cycles_to_distance =
                @monitoring_info.cycles_to_distance[idx]
              running_cycles_to_calories =
                @monitoring_info.cycles_to_calories[idx]
            end
          end
          distance = total_distance.values.inject(0.0, :+)
          calories = total_calories.values.inject(0.0, :+) +
            @monitoring_info.resting_metabolic_rate
        end
      end

      { :steps => ((total_cycles['walking'] + total_cycles['running']) * 2 +
                   total_cycles['generic']).to_i,
        :distance => distance, :calories => calories }
    end

    def intensity_minutes
      moderate_minutes = vigorous_minutes = 0.0
      @samples.each do |s|
        if s.weekly_moderate_activity_minutes &&
           s.weekly_moderate_activity_minutes > moderate_minutes
          moderate_minutes = s.weekly_moderate_activity_minutes
        end
        if s.weekly_vigorous_activity_minutes &&
           s.weekly_vigorous_activity_minutes > vigorous_minutes
          vigorous_minutes = s.weekly_vigorous_activity_minutes
        end
      end

      { :moderate_minutes => moderate_minutes,
        :vigorous_minutes => vigorous_minutes }
    end

    def steps_goal
      if @monitoring_info && @monitoring_info.goal_cycles &&
         @monitoring_info.goal_cycles[0]
        @monitoring_info.goal_cycles[0]
      else
        0
      end
    end

    def samples
      @samples.length
    end

    private

    def get_monitoring_info(monitoring_file)
      # The monitoring files have a monitoring_info section that contains a
      # timestamp in UTC and a local_time field for the same time in the local
      # time. If any of that isn't present, we use an offset of 0.
      if (mis = monitoring_file.monitoring_infos).nil? || mis.empty? ||
         (mi = mis[0]).nil? || mi.local_time.nil? || mi.timestamp.nil?
        return nil
      end

      mi
    end

    # Load monitoring data from monitoring_b FIT files into Arrays.
    # @param monitoring_files [Array of Monitoring_B] FIT files to read
    # @param day [Time] Midnight UTC of the day to analyze
    def extract_data_from_monitor_files(monitoring_files, day)
      monitoring_files.each do |mf|
        next unless (mi = get_monitoring_info(mf))

        utc_offset = mi.local_time - mi.timestamp
        # Midnight (local time) of the requested day.
        window_start_time = day - utc_offset
        # Midnight (local time) of the next day
        window_end_time = window_start_time + 24 * 60 * 60

        # Ignore all files with data prior to the potential time window.
        next if mf.monitorings.empty? ||
                mf.monitorings.last.timestamp < window_start_time

        if @utc_offset.nil?
          # The instance variables will only be set once we have found our
          # first monitoring file that matches the requested day. We use the
          # local time setting for this first file even if it changes in
          # subsequent files.
          @window_start_time = window_start_time
          @window_end_time = window_end_time
          @utc_offset = utc_offset
        end

        if @monitoring_info.nil? && @window_start_time <= mi.local_time &&
           mi.local_time < @window_end_time
          @monitoring_info = mi
        end

        mf.monitorings.each do |m|
          # Ignore all entries outside our time window. It's important to note
          # that records with a midnight timestamp contain totals from the day
          # before.
          next if m.timestamp <= @window_start_time ||
                  m.timestamp > @window_end_time

          @samples << MonitoringSample.new(m)
        end
      end

      unless @window_start_time
        raise RuntimeError, "No window start time set for day #{day}"
      end
    end

  end

end

