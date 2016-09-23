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

require 'postrunner/SleepCycle'

module PostRunner

  # This class extracts the sleep information from a set of monitoring files
  # and determines when and how long the user was awake or had a light or deep
  # sleep. Determining the sleep state of a person purely based on wrist
  # movement data is not very accurate. It gets a lot more accurate when heart
  # rate data is available as well. The heart rate describes a sinus-like
  # curve that aligns with the sleep cycles. Each sinus cycle corresponds to a
  # sleep cycle. Unfortunately, current Garmin devices only use a default
  # sampling time of 15 minutes. Since a sleep cycle is broken down into
  # various sleep phases that normally last 10 - 15 minutes, there is a fairly
  # high margin of error to determine the exact timing of the sleep cycle.
  #
  # HR High  -----+   +-------+        +------+
  # HR Low        +---+       +--------+      +---
  # Mov High --+         +-------+  +-----+     +--
  # Mov Low    +---------+       +--+     +-----+
  # Phase   wk n1  n3 n2 rem n2 n3 n2 rem n2 n3 n2
  # Cycle     1               2               3
  #
  # Legend: wk: wake n1: NREM1, n2: NREM2, n3: NREM3, rem: REM sleep
  #
  # Too frequent or too strong movements abort the cycle to wake.
  class DailySleepAnalyzer

    attr_reader :sleep_cycles, :utc_offset,
                :total_sleep, :rem_sleep, :deep_sleep, :light_sleep,
                :resting_heart_rate, :window_start_time, :window_end_time

    TIME_WINDOW_MINUTES = 24 * 60

    # Create a new DailySleepAnalyzer object to analyze the given monitoring
    # files.
    # @param monitoring_files [Array] A set of Monitoring_B objects
    # @param day [String] Day to analyze as YY-MM-DD string
    # @param window_offest_secs [Fixnum] Offset (in seconds) of the time
    #        window to analyze against the midnight of the specified day
    def initialize(monitoring_files, day, window_offest_secs)
      @window_start_time = @window_end_time = @utc_offset = nil

      # The following activity types are known:
      #  [ :undefined, :running, :cycling, :transition,
      #    :fitness_equipment, :swimming, :walking, :unknown7,
      #    :resting, :unknown9 ]
      @activity_type = Array.new(TIME_WINDOW_MINUTES, nil)
      # The activity values in the FIT files can range from 0 to 7.
      @activity_intensity = Array.new(TIME_WINDOW_MINUTES, nil)
      # Wrist motion data is not very well suited to determine wake or sleep
      # states. A single movement can be a turning motion, a NREM1 jerk or
      # even a movement while you dream. The fewer motions are detected, the
      # more likely you are really asleep. To even out single spikes, we
      # average the motions over a period of time. This Array stores the
      # weighted activity.
      @weighted_sleep_activity = Array.new(TIME_WINDOW_MINUTES, 8)
      # We classify the sleep activity into :wake, :low_activity and
      # :no_activity in this Array.
      @sleep_activity_classification = Array.new(TIME_WINDOW_MINUTES, nil)

      # The data from the monitoring files is stored in Arrays that cover 24
      # hours at 1 minute resolution. The algorithm currently cannot handle
      # time zone or DST changes. The day is always 24 hours and the local
      # time at noon the previous day is used for the whole window.
      @heart_rate = Array.new(TIME_WINDOW_MINUTES, nil)
      # From the wrist motion data and if available from the heart rate data,
      # we try to guess the sleep phase (:wake, :rem, :nrem1, :nrem2, :nrem3).
      # This Array will hold a minute-by-minute list of the guessed sleep
      # phase.
      @sleep_phase = Array.new(TIME_WINDOW_MINUTES, :wake)
      # The DailySleepAnalzyer extracts the sleep cycles from the monitoring
      # data. Each night usually has 5 - 6 sleep cycles. If we have heart rate
      # data, those cycles can be identified fairly well. If we have to rely
      # on wrist motion data only, we usually find more cycles than there
      # actually were. Each cycle is captured as SleepCycle object.
      @sleep_cycles = []
      # The resting heart rate.
      @resting_heart_rate = nil

      # Day as Time object. Midnight UTC.
      day_as_time = Time.parse(day + "-00:00:00+00:00").gmtime
      extract_data_from_monitor_files(monitoring_files, day_as_time,
                                      window_offest_secs)

      # We must have information about the local time zone the data was
      # recorded in. Abort if not available.
      return unless @utc_offset

      fill_monitoring_data
      categorize_sleep_activity

      if categorize_sleep_heart_rate
        # We have usable heart rate data for the sleep periods. Correlating
        # wrist motion data with heart rate cycles will greatly improve the
        # sleep phase and sleep cycle detection.
        categorize_sleep_phase_by_hr_level
        @sleep_cycles.each do |c|
          # Adjust the cycle boundaries to align with REM phase.
          c.adjust_cycle_boundaries(@sleep_phase)
          # Detect sleep phases for each cycle.
          c.detect_phases(@sleep_phase)
        end
      else
        # We have no usable heart rate data. Just guess sleep phases based on
        # wrist motion data.
        categorize_sleep_phase_by_activity_level
        @sleep_cycles.each { |c| c.detect_phases(@sleep_phase) }
      end
      dump_data
      delete_wake_cycles
      determine_resting_heart_rate
      calculate_totals
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
    # @param window_offest_secs [Fixnum] Difference between midnight and the
    #        start of the time window to analyze.
    def extract_data_from_monitor_files(monitoring_files, day,
                                        window_offest_secs)
      monitoring_files.each do |mf|
        next unless (mi = get_monitoring_info(mf))

        utc_offset = mi.local_time - mi.timestamp
        # Midnight (local time) of the requested day.
        midnight_today = day - utc_offset
        # Noon (local time) the day before the requested day. The time object
        # is UTC for the noon time in the local time zone.
        window_start_time = midnight_today + window_offest_secs
        # Noon (local time) of the current day
        window_end_time = window_start_time + TIME_WINDOW_MINUTES * 60

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

        mf.monitorings.each do |m|
          # Ignore all entries outside our time window.
          next if m.timestamp < @window_start_time ||
                  m.timestamp >= @window_end_time

          # The index (minutes after noon yesterday) to address all the value
          # arrays.
          index = (m.timestamp - @window_start_time) / 60

          # The activity type and intensity are stored in the same FIT field.
          # We'll break them into 2 separate values.
          if (cati = m.current_activity_type_intensity)
            @activity_type[index] = cati & 0x1F
            @activity_intensity[index] = (cati >> 5) & 0x7
          end

          # Store heart rate data if available.
          if m.heart_rate
            @heart_rate[index] = m.heart_rate
          end
        end
      end

    end

    def fill_monitoring_data
      # The FIT files only contain a timestamped entry when new values have
      # been measured. The timestamp marks the end of the period where the
      # recorded values were current.
      #
      # We want to have an entry for every minute. So we have to replicate the
      # found value for all previous minutes until we find another valid
      # entry.
      current = nil
      [ @activity_type, @activity_intensity, @heart_rate ].each do |dataset|
        current = nil
        # We need to fill back-to-front, so we reverse the array during the
        # fill. And reverse it back at the end.
        dataset.reverse!.map! do |v|
          v.nil? ? current : current = v
        end.reverse!
      end
    end

    # Dump all input and intermediate data for the sleep tracking into a CSV
    # file if DEBUG mode is enabled.
    def dump_data
      if $DEBUG
        File.open('monitoring-data.csv', 'w') do |f|
          f.puts 'Date;Activity Type;Activity Level;Weighted Act. Level;' +
                 'Heart Rate;Activity Class;Heart Rate Class;Sleep Phase'
          0.upto(TIME_WINDOW_MINUTES - 1) do |i|
            at = @activity_type[i]
            ai = @activity_intensity[i]
            wsa = @weighted_sleep_activity[i]
            hr = @heart_rate[i]
            sac = @sleep_activity_classification[i]
            shc = @sleep_heart_rate_classification[i]
            sp = @sleep_phase[i]
            f.puts "#{@window_start_time + i * 60};" +
                   "#{at.is_a?(Fixnum) ? at : ''};" +
                   "#{ai.is_a?(Fixnum) ? ai : ''};" +
                   "#{wsa};" +
                   "#{hr.is_a?(Fixnum) ? hr : ''};" +
                   "#{sac ? sac.to_s : ''};" +
                   "#{shc ? shc.to_s : ''};" +
                   "#{sp.to_s}"
          end
        end
      end
    end

    def categorize_sleep_activity
      delta = 7
      0.upto(TIME_WINDOW_MINUTES - 1) do |i|
        intensity_sum = 0
        weight_sum = 0

        (i - delta).upto(i + delta) do |j|
          next if i < 0 || i >= TIME_WINDOW_MINUTES

          weight = delta - (i - j).abs
          intensity_sum += weight *
            (@activity_type[j] != 8 ? 8 : @activity_intensity[j])
          weight_sum += weight
        end

        # Normalize the weighted intensity sum
        @weighted_sleep_activity[i] =
          intensity_sum.to_f / weight_sum

        @sleep_activity_classification[i] =
          if @weighted_sleep_activity[i] > 2.2
            :wake
          elsif @weighted_sleep_activity[i] > 0.5
            :low_activity
          else
            :no_activity
          end
      end
    end

    # During the nightly sleep the heart rate is alternating between a high
    # and a low frequency. The actual frequencies vary so that we need to look
    # for the transitions to classify each sample as high or low. Research has
    # shown that sleep cycles are roughly 90 minutes long. The early cycles
    # have a lot more deep sleep (low HR) and less REM (high HR) while with
    # every cycle the deep sleep phase shortens and the REM phase gets longer.
    # We assume that a normalized half-phase is at least 25 minutes long and
    # the weight shifts by 4 minutes towards the high HR (REM) phase with
    # every phase.
    def categorize_sleep_heart_rate
      @sleep_heart_rate_classification = Array.new(TIME_WINDOW_MINUTES, nil)

      last_heart_rate = 0
      current_category = :high_hr
      last_transition_index = 0
      last_transition_delta = 0
      transitions = 0

      0.upto(TIME_WINDOW_MINUTES - 1) do |i|
        if @sleep_activity_classification[i] == :wake ||
           @heart_rate[i].nil? || @heart_rate[i] == 0
          last_heart_rate = 0
          current_category = :high_hr
          last_transition_index = i + 1
          last_transition_delta = 0
          next
        end

        if last_heart_rate
          if current_category == :high_hr
            if last_heart_rate > @heart_rate[i]
              # High/low transition found
              if i - last_transition_index >= 25 - 2 * transitions
                current_category = :low_hr
                transitions += 1
                last_transition_delta = last_heart_rate - @heart_rate[i]
                last_transition_index = i
              end
            elsif last_heart_rate < @heart_rate[i] &&
                  last_transition_delta < @heart_rate[i] - last_heart_rate
              # The previously found high segment was wrongly categorized as
              # such. Convert it to low segment.
              last_transition_index.upto(i - 1) do |j|
                @sleep_heart_rate_classification[j] = :low_hr
              end
              # Now we are in a high segment.
              current_category = :high_hr
              last_transition_delta += @heart_rate[i] - last_heart_rate
              last_transition_index = i
            end
          else
            if last_heart_rate < @heart_rate[i]
              # Low/High transition found.
              if i - last_transition_index >= 25 + 2 * transitions
                current_category = :high_hr
                transitions += 1
                last_transition_delta = @heart_rate[i] - last_heart_rate
                last_transition_index = i
              end
            elsif last_heart_rate > @heart_rate[i] &&
                  last_transition_delta < last_heart_rate - @heart_rate[i]
              # The previously found low segment was wrongly categorized as
              # such. Convert it to high segment.
              last_transition_index.upto(i - 1) do |j|
                @sleep_heart_rate_classification[j] = :high_hr
              end
              # Now we are in a low segment.
              current_category = :low_hr
              last_transition_delta += last_heart_rate - @heart_rate[i]
              last_transition_index = i
            end
          end
          @sleep_heart_rate_classification[i] = current_category
        end

        last_heart_rate = @heart_rate[i]
      end

      # We consider the HR transition data good enough if we have found at
      # least 3 transitions.
      transitions > 3
    end

    # Use the wrist motion data and heart rate data to guess the sleep phases
    # and sleep cycles.
    def categorize_sleep_phase_by_hr_level
      rem_possible = false
      current_hr_phase = nil
      cycle = nil

      0.upto(TIME_WINDOW_MINUTES - 1) do |i|
        sac = @sleep_activity_classification[i]
        hrc = @sleep_heart_rate_classification[i]

        if hrc != current_hr_phase
          if current_hr_phase.nil?
            if hrc == :high_hr
              # Wake/High transition.
              rem_possible = false
            else
              # Wake/Low transition. Should be very uncommon.
              rem_possible = true
            end
            cycle = SleepCycle.new(@window_start_time, i)
          elsif current_hr_phase == :high_hr
            rem_possible = false
            if hrc.nil?
              # High/Wake transition. Wakeing up from light sleep.
              if cycle
                cycle.end_idx = i - 1
                @sleep_cycles << cycle
                cycle = nil
              end
            else
              # High/Low transition. Going into deep sleep
              if cycle
                # A high/low transition completes the cycle if we already have
                # a low/high transition for this cycle. The actual end
                # should be the end of the REM phase, but we have to correct
                # this and the start of the new cycle later.
                cycle.high_low_trans_idx = i
                if cycle.low_high_trans_idx
                  cycle.end_idx = i - 1
                  @sleep_cycles << cycle
                  cycle = SleepCycle.new(@window_start_time, i, cycle)
                end
              end
            end
          else
            if hrc.nil?
              # Low/Wake transition. Waking up from deep sleep.
              rem_possible = false
              if cycle
                cycle.end_idx = i - 1
                @sleep_cycles << cycle
                cycle = nil
              end
            else
              # Low/High transition. REM phase possible
              rem_possible = true
              cycle.low_high_trans_idx = i if cycle
            end
          end
        end
        current_hr_phase = hrc

        next unless hrc && sac

        @sleep_phase[i] =
          if hrc == :high_hr
            if sac == :no_activity
              :nrem1
            else
              rem_possible ? :rem : :nrem1
            end
          else
            if sac == :no_activity
              :nrem3
            else
              :nrem2
            end
          end
      end
    end

    def categorize_sleep_phase_by_activity_level
      @sleep_phase = []
      mappings = { :wake => :wake, :low_activity => :nrem1,
                   :no_activity => :nrem3 }

      current_cycle_start = nil
      current_phase = @sleep_activity_classification[0]
      current_phase_start = 0

      0.upto(TIME_WINDOW_MINUTES - 1) do |idx|
        # Without HR data, we need to use other threshold values to determine
        # the activity classification. Hence we do it again here.
        @sleep_activity_classification[idx] = sac =
          if @weighted_sleep_activity[idx] > 2.2
            :wake
          elsif @weighted_sleep_activity[idx] > 0.01
            :low_activity
          else
            :no_activity
          end

        @sleep_phase << mappings[sac]

        # Sleep cycles start at wake/non-wake transistions.
        if current_cycle_start.nil? && sac != :wake
          current_cycle_start = idx
        end

        if current_phase != sac || idx >= TIME_WINDOW_MINUTES
          # We have detected the end of a phase.
          if (current_phase == :no_activity || sac == :wake) &&
             current_cycle_start
            # The end of the :no_activity phase marks the end of a sleep cycle.
            @sleep_cycles << (cycle = SleepCycle.new(@window_start_time,
                                                     current_cycle_start,
                                                     @sleep_cycles.last))
            cycle.end_idx = idx
            current_cycle_start = nil
          end

          current_phase = sac
          current_phase_start = idx
        end
      end
    end

    def delete_wake_cycles
      wake_cycles = []
      @sleep_cycles.each { |c| wake_cycles << c if c.is_wake_cycle? }

      wake_cycles.each { |c| c.unlink }
      @sleep_cycles.delete_if { |c| wake_cycles.include?(c) }
    end

    def determine_resting_heart_rate
      # Find the smallest heart rate. TODO: While being awake.
      @heart_rate.each_with_index do |heart_rate, idx|
        next unless heart_rate && heart_rate > 0 &&
                    @activity_type[idx] != :resting

        if @resting_heart_rate.nil? || @resting_heart_rate > heart_rate
          @resting_heart_rate = heart_rate
        end
      end
    end

    def calculate_totals
      @total_sleep = @light_sleep = @deep_sleep = @rem_sleep = 0

      @sleep_cycles.each do |p|
        @total_sleep += p.total_seconds.values.inject(0, :+)
        @light_sleep += p.total_seconds[:nrem1] + p.total_seconds[:nrem2]
        @deep_sleep += p.total_seconds[:nrem3]
        @rem_sleep += p.total_seconds[:rem]
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

