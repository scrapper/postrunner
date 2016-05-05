#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SleepStatistics.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/DailySleepAnalyzer'
require 'postrunner/FlexiTable'

module PostRunner

  # This class can be used to generate reports for sleep data. It uses the
  # DailySleepAnalyzer class to compute the data and generates the report for
  # a certain time period.
  class SleepStatistics

    include Fit4Ruby::Converters

    # Create a new SleepStatistics object.
    # @param monitoring_files [Array of Fit4Ruby::Monitoring_B] FIT files
    def initialize(monitoring_files)
      @monitoring_files = monitoring_files
    end

    # Generate a report for a certain day.
    # @param day [String] Date of the day as YYYY-MM-DD string.
    def daily(day)
      analyzer = DailySleepAnalyzer.new(@monitoring_files, day, -12 * 60 * 60)

      if analyzer.sleep_cycles.empty?
        return 'No sleep data available for this day'
      end

      "Sleep Statistics for #{day}\n\n" +
        daily_sleep_cycle_table(analyzer).to_s
    end

    def monthly(day)
      day_as_time = Time.parse(day)
      year = day_as_time.year
      month = day_as_time.month
      last_day_of_month = Date.new(year, month, -1).day

      t = FlexiTable.new
      left = { :halign => :left }
      right = { :halign => :right }
      t.set_column_attributes([ left, right, right, right, right, right ])
      t.head
      t.row([ 'Date', 'Total Sleep', 'REM Sleep', 'Deep Sleep',
              'Light Sleep', 'RHR' ])
      t.body
      totals = Hash.new(0)
      counted_days = 0
      rhr_days = 0

      1.upto(last_day_of_month).each do |dom|
        day_str = Time.new(year, month, dom).strftime('%Y-%m-%d')
        t.cell(day_str)

        analyzer = DailySleepAnalyzer.new(@monitoring_files, day_str,
                                          -12 * 60 * 60)

        if (analyzer.sleep_cycles.empty?)
          4.times { t.cell('-') }
        else
          totals[:total_sleep] += analyzer.total_sleep
          totals[:rem_sleep] += analyzer.rem_sleep
          totals[:deep_sleep] += analyzer.deep_sleep
          totals[:light_sleep] += analyzer.light_sleep
          counted_days += 1

          t.cell(secsToHM(analyzer.total_sleep))
          t.cell(secsToHM(analyzer.rem_sleep))
          t.cell(secsToHM(analyzer.deep_sleep))
          t.cell(secsToHM(analyzer.light_sleep))
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
        t.cell(secsToHM(totals[:rem_sleep] / counted_days))
        t.cell(secsToHM(totals[:deep_sleep] / counted_days))
        t.cell(secsToHM(totals[:light_sleep] / counted_days))
      else
        3.times { t.cell('-') }
      end
      if rhr_days > 0
        t.cell('%.1f' % (totals[:rhr] / rhr_days))
      else
        t.cell('-')
      end
      t.new_row

      "Sleep Statistics for #{day_as_time.strftime('%B')} #{year}\n\n#{t}"
    end

    private

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

  end

end

