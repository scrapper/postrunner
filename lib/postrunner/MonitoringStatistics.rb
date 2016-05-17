#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MonitoringStatistics.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/DailySleepAnalyzer'
require 'postrunner/DailyMonitoringAnalyzer'
require 'postrunner/FlexiTable'

module PostRunner

  # This class can be used to generate reports for sleep data. It uses the
  # DailySleepAnalyzer class to compute the data and generates the report for
  # a certain time period.
  class MonitoringStatistics

    include Fit4Ruby::Converters

    # Create a new MonitoringStatistics object.
    # @param monitoring_files [Array of Fit4Ruby::Monitoring_B] FIT files
    def initialize(monitoring_files)
      @monitoring_files = monitoring_files
    end

    # Generate a report for a certain day.
    # @param day [String] Date of the day as YYYY-MM-DD string.
    def daily(day)
      sleep_analyzer = DailySleepAnalyzer.new(@monitoring_files, day,
                                              +12 * 60 * 60)
      monitoring_analyzer = DailyMonitoringAnalyzer.new(@monitoring_files, day)

      str = "Daily Monitoring Report for #{day}\n\n" +
            "#{daily_goals_table(monitoring_analyzer)}\n" +
            "#{daily_stats_table(monitoring_analyzer, sleep_analyzer)}\n"
      if sleep_analyzer.sleep_cycles.empty?
        str += 'No sleep data available for this day'
      else
        str += "Sleep Statistics for " +
               "#{sleep_analyzer.window_start_time.strftime('%Y-%m-%d')} - " +
               "#{sleep_analyzer.window_end_time.strftime('%Y-%m-%d')}\n\n" +
          daily_sleep_cycle_table(sleep_analyzer).to_s
      end

      str
    end

    # Generate a report for a certain month.
    # @param day [String] Date of a day in that months as YYYY-MM-DD string.
    def monthly(day)
      day_as_time = Time.parse(day)
      year = day_as_time.year
      month = day_as_time.month
      last_day_of_month = Date.new(year, month, -1).day

      "Monitoring Statistics for #{day_as_time.strftime('%B %Y')}\n\n" +
        monthly_goal_table(year, month, last_day_of_month).to_s + "\n" +
        monthly_sleep_table(year, month, last_day_of_month).to_s
    end

    private

    def percent(value, total)
      "#{'%.0f' % ((value * 100.0) / total)}%"
    end

    def cell_right_aligned(table, text)
      table.cell(text, { :halign => :right })
    end

    def time_as_hm(t, utc_offset)
      t.localtime(utc_offset).strftime('%H:%M')
    end

    def daily_sleep_cycle_table(analyzer)
      ti = FlexiTable.new
      ti.head
      ti.row([ 'Cycle', 'From', 'To', 'Duration', 'REM Sleep',
               'Light Sleep', 'Deep Sleep'])
      ti.body
      utc_offset = analyzer.utc_offset
      format = { :halign => :right }
      totals = Hash.new(0)
      last_to_time = nil
      analyzer.sleep_cycles.each_with_index do |c, idx|
        if last_to_time && c.from_time > last_to_time
          # We have a gap in the sleep cycles.
          ti.cell('Wake')
          cell_right_aligned(ti, time_as_hm(last_to_time, utc_offset))
          cell_right_aligned(ti, time_as_hm(c.from_time, utc_offset))
          cell_right_aligned(ti, "(#{secsToHM(c.from_time - last_to_time)})")
          ti.cell('')
          ti.cell('')
          ti.cell('')
          ti.new_row
        end

        ti.cell((idx + 1).to_s, format)
        ti.cell(c.from_time.localtime(utc_offset).strftime('%H:%M'), format)
        ti.cell(c.to_time.localtime(utc_offset).strftime('%H:%M'), format)

        duration = c.to_time - c.from_time
        totals[:duration] += duration
        ti.cell(secsToHM(duration), format)

        totals[:rem] += c.total_seconds[:rem]
        ti.cell(secsToHM(c.total_seconds[:rem]), format)

        light_sleep = c.total_seconds[:nrem1] + c.total_seconds[:nrem2]
        totals[:light_sleep] += light_sleep
        ti.cell(secsToHM(light_sleep), format)

        totals[:deep_sleep] += c.total_seconds[:nrem3]
        ti.cell(secsToHM(c.total_seconds[:nrem3]), format)

        ti.new_row
        last_to_time = c.to_time
      end
      ti.foot
      ti.cell('Totals')
      ti.cell(analyzer.sleep_cycles[0].from_time.localtime(utc_offset).
              strftime('%H:%M'), format)
      ti.cell(analyzer.sleep_cycles[-1].to_time.localtime(utc_offset).
              strftime('%H:%M'), format)
      ti.cell(secsToHM(totals[:duration]), format)
      ti.cell(secsToHM(totals[:rem]), format)
      ti.cell(secsToHM(totals[:light_sleep]), format)
      ti.cell(secsToHM(totals[:deep_sleep]), format)
      ti.new_row

      ti
    end

    def daily_goals_table(monitoring_analyzer)
      t = FlexiTable.new

      t.head
      t.row([ 'Steps', 'Intensity Minutes', 'Floors Climbed' ])

      t.body
      t.set_column_attributes(Array.new(3, { :halign => :center}))

      steps_distance_calories = monitoring_analyzer.steps_distance_calories
      steps = steps_distance_calories[:steps]
      steps_goal = monitoring_analyzer.steps_goal
      t.cell(steps)

      intensity_minutes = weekly_intensity_minutes(monitoring_analyzer)
      t.cell(intensity_minutes)

      floors = monitoring_analyzer.total_floors
      floors_climbed = floors[:floors_climbed]
      t.cell(floors_climbed)
      t.new_row

      t.cell("#{percent(steps, steps_goal)} of daily goal #{steps_goal}")
      t.cell("#{percent(intensity_minutes, 150)} of weekly goal 150")
      t.cell("#{percent(floors_climbed, 10)} of daily goal 10")
      t.new_row

      t
    end

    def daily_stats_table(monitoring_analyzer, sleep_analyzer)
      t = FlexiTable.new
      t.set_column_attributes(Array.new(4, { :halign => :center}))

      t.head
      t.row([ 'Distance', 'Calories', 'Floors descended',
              'Resting Heart Rate' ])

      t.body
      steps_distance_calories = monitoring_analyzer.steps_distance_calories
      t.cell("#{'%.1f' % (steps_distance_calories[:distance] / 1000.0)} km")

      t.cell("#{steps_distance_calories[:calories].to_i}")

      floors = monitoring_analyzer.total_floors
      t.cell("#{floors[:floors_descended]}")

      t.cell("#{sleep_analyzer.resting_heart_rate} BPM")

      t
    end

    def monthly_goal_table(year, month, last_day_of_month)
      t = FlexiTable.new
      left = { :halign => :left }
      right = { :halign => :right }
      t.set_column_attributes([ left ] + [ right ] * 7)
      t.head
      t.row([ 'Date', 'Steps', '%', 'Goal', 'Intensity', '%',
              'Floors', '% of 10' ])
      t.row([ '', '', '', '', 'Minutes', 'Week', '', '' ])
      t.body
      totals = Hash.new(0)
      counted_days = 0
      weekly_intensity_minutes = 0
      1.upto(last_day_of_month).each do |dom|
        break if (time = Time.new(year, month, dom)) > Time.now

        day_str = time.strftime('%Y-%m-%d')
        t.cell(day_str)

        analyzer = DailyMonitoringAnalyzer.new(@monitoring_files, day_str)

        steps_distance_calories = analyzer.steps_distance_calories
        steps = steps_distance_calories[:steps]
        totals[:steps] += steps
        steps_goal = analyzer.steps_goal
        totals[:steps_goal] += steps_goal
        t.cell(steps)
        t.cell(percent(steps, steps_goal))
        t.cell(steps_goal)

        weekly_intensity_minutes = 0 if time.wday == 1
        intensity_minutes =
          analyzer.intensity_minutes[:moderate_minutes] +
          2 * analyzer.intensity_minutes[:vigorous_minutes]
        weekly_intensity_minutes += intensity_minutes
        totals[:intensity_minutes] += intensity_minutes
        t.cell(weekly_intensity_minutes.to_i)
        t.cell(percent(weekly_intensity_minutes, 150))

        floors = analyzer.total_floors
        floors_climbed = floors[:floors_climbed]
        totals[:floors] += floors_climbed
        t.cell(floors_climbed)
        t.cell(percent(floors_climbed, 10))
        t.new_row
        counted_days += 1
      end

      t.foot
      t.cell('Totals')
      t.cell(totals[:steps])
      t.cell('')
      t.cell(totals[:steps_goal])
      t.cell(totals[:intensity_minutes].to_i)
      t.cell('')
      t.cell(totals[:floors])
      t.cell('')
      t.new_row

      if counted_days > 0
        t.cell('Averages')
        t.cell((totals[:steps] / counted_days).to_i)
        t.cell(percent(totals[:steps], totals[:steps_goal]))
        t.cell((totals[:steps_goal] / counted_days).to_i)
        t.cell((totals[:intensity_minutes] / counted_days).to_i)
        t.cell(percent(totals[:intensity_minutes], (counted_days / 7.0) * 150))
        t.cell((totals[:floors] / counted_days).to_i)
        t.cell(percent(totals[:floors] / counted_days, 10))
      end

      t
    end

    def monthly_sleep_table(year, month, last_day_of_month)
      t = FlexiTable.new
      left = { :halign => :left }
      right = { :halign => :right }
      t.set_column_attributes([ left ] + [ right ] * 6)
      t.head
      t.row([ 'Date', 'Total Sleep', 'Cycles', 'REM Sleep', 'Light Sleep',
              'Deep Sleep', 'RHR' ])
      t.body
      totals = Hash.new(0)
      counted_days = 0
      rhr_days = 0

      1.upto(last_day_of_month).each do |dom|
        break if (time = Time.new(year, month, dom)) > Time.now

        day_str = time.strftime('%Y-%m-%d')
        t.cell(day_str)

        analyzer = DailySleepAnalyzer.new(@monitoring_files, day_str,
                                          -12 * 60 * 60)

        if (analyzer.sleep_cycles.empty?)
          5.times { t.cell('-') }
        else
          totals[:total_sleep] += analyzer.total_sleep
          totals[:cycles] += analyzer.sleep_cycles.length
          totals[:rem_sleep] += analyzer.rem_sleep
          totals[:light_sleep] += analyzer.light_sleep
          totals[:deep_sleep] += analyzer.deep_sleep
          counted_days += 1

          t.cell(secsToHM(analyzer.total_sleep))
          t.cell(analyzer.sleep_cycles.length)
          t.cell(secsToHM(analyzer.rem_sleep))
          t.cell(secsToHM(analyzer.light_sleep))
          t.cell(secsToHM(analyzer.deep_sleep))
        end

        if (rhr = analyzer.resting_heart_rate) && rhr > 0
          t.cell(rhr)
          totals[:rhr] += rhr
          rhr_days += 1
        else
          t.cell('-')
        end
        t.new_row
      end
      t.foot
      t.cell('Averages')
      if counted_days > 0
        t.cell(secsToHM(totals[:total_sleep] / counted_days))
        t.cell('%.1f' % (totals[:cycles] / counted_days))
        t.cell(secsToHM(totals[:rem_sleep] / counted_days))
        t.cell(secsToHM(totals[:light_sleep] / counted_days))
        t.cell(secsToHM(totals[:deep_sleep] / counted_days))
      else
        5.times { t.cell('-') }
      end
      if rhr_days > 0
        t.cell('%.0f' % (totals[:rhr] / rhr_days))
      else
        t.cell('-')
      end
      t.new_row

      t
    end

    def weekly_intensity_minutes(monitoring_analyzer)
      current_date = monitoring_analyzer.window_start_time

      intensity_minutes = 0
      # Need to find a way to get intensity minutes for previous days.
      #1.upto(current_date.wday) do |i|
      #  date = current_date - 24 * 60 * 60 * i
      #  ma = DailyMonitoringAnalyzer.new(date.strftime('%Y-%m-%d'))
      #  intensity_minutes +=
      #    ma.intensity_minutes[:moderate_minutes] +
      #    2 * ma.intensity_minutes[:vigorous_minutes]
      #end
      intensity_minutes +=
        monitoring_analyzer.intensity_minutes[:moderate_minutes] +
        2 * monitoring_analyzer.intensity_minutes[:vigorous_minutes]

      intensity_minutes
    end

  end

end

