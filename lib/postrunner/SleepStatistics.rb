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
      analyzer = DailySleepAnalyzer.new(@monitoring_files, day)

      if analyzer.sleep_intervals.empty?
        return 'No sleep data available for this day'
      end

      ti = FlexiTable.new
      ti.head
      ti.row([ 'From', 'To', 'Sleep phase' ])
      ti.body
      utc_offset = analyzer.utc_offset
      analyzer.sleep_intervals.each do |i|
        ti.cell(i[:from_time].localtime(utc_offset).strftime('%H:%M'))
        ti.cell(i[:to_time].localtime(utc_offset).strftime('%H:%M'))
        ti.cell(i[:phase])
        ti.new_row
      end

      tt = FlexiTable.new
      tt.head
      tt.row([ 'Total Sleep', 'Deep Sleep', 'Light Sleep' ])
      tt.body
      tt.cell(secsToHM(analyzer.total_sleep), { :halign => :right })
      tt.cell(secsToHM(analyzer.deep_sleep), { :halign => :right })
      tt.cell(secsToHM(analyzer.light_sleep), { :halign => :right })
      tt.new_row

      "Sleep Statistics for #{day}\n\n#{ti}\n#{tt}"
    end

    def monthly(day)
      day_as_time = Time.parse(day)
      year = day_as_time.year
      month = day_as_time.month
      last_day_of_month = Date.new(year, month, -1).day

      t = FlexiTable.new
      left = { :halign => :left }
      right = { :halign => :right }
      t.set_column_attributes([ left, right, right, right ])
      t.head
      t.row([ 'Date', 'Total Sleep', 'Deep Sleep', 'Light Sleep' ])
      t.body
      totals = Hash.new(0)
      counted_days = 0

      1.upto(last_day_of_month).each do |dom|
        day_str = Time.new(year, month, dom).strftime('%Y-%m-%d')
        t.cell(day_str)

        analyzer = DailySleepAnalyzer.new(@monitoring_files, day_str)

        if analyzer.sleep_intervals.empty?
          t.cell('-')
          t.cell('-')
          t.cell('-')
        else
          totals[:total_sleep] += analyzer.total_sleep
          totals[:deep_sleep] += analyzer.deep_sleep
          totals[:light_sleep] += analyzer.light_sleep
          counted_days += 1

          t.cell(secsToHM(analyzer.total_sleep))
          t.cell(secsToHM(analyzer.deep_sleep))
          t.cell(secsToHM(analyzer.light_sleep))
        end
        t.new_row
      end
      t.foot
      t.cell('Averages')
      t.cell(secsToHM(totals[:total_sleep] / counted_days))
      t.cell(secsToHM(totals[:deep_sleep] / counted_days))
      t.cell(secsToHM(totals[:light_sleep] / counted_days))
      t.new_row

      "Sleep Statistics for #{day_as_time.strftime('%B')} #{year}\n\n#{t}"
    end

  end

end

