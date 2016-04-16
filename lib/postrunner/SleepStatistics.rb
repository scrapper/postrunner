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

  end

end

