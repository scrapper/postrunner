#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivitySummary.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/FlexiTable'
require 'postrunner/ViewWidgets'

module PostRunner

  class ActivitySummary

    include Fit4Ruby::Converters
    include ViewWidgets

    def initialize(fit_activity, name, unit_system)
      @fit_activity = fit_activity
      @name = name
      @unit_system = unit_system
    end

    def to_s
      summary.to_s + "\n" + laps.to_s
    end

    def to_html(doc)
      frame(doc, "Activity: #{@name}") {
        summary.to_html(doc)
      }
      frame(doc, 'Laps') {
        laps.to_html(doc)
      }
    end

    private

    def summary
      session = @fit_activity.sessions[0]

      t = FlexiTable.new
      t.enable_frame(false)
      t.body
      t.row([ 'Date:', session.timestamp])
      t.row([ 'Distance:',
              local_value(session, 'total_distance', '%.2f %s',
                          { :metric => 'km', :statute => 'mi'}) ])
      t.row([ 'Time:', secsToHMS(session.total_timer_time) ])
      if session.sport == 'running'
        t.row([ 'Avg. Pace:', pace(session, 'avg_speed') ])
      else
        t.row([ 'Avg. Speed:',
                local_value(session, 'avg_speed', '%.1f %s',
                            { :metric => 'km/h', :statute => 'mph' }) ])
      end
      t.row([ 'Total Ascent:',
              local_value(session, 'total_ascent', '%.0f %s',
                          { :metric => 'm', :statute => 'ft' }) ])
      t.row([ 'Total Descent:',
              local_value(session, 'total_descent', '%.0f %s',
                          { :metric => 'm', :statute => 'ft' }) ])
      t.row([ 'Calories:', "#{session.total_calories} kCal" ])
      t.row([ 'Avg. HR:', session.avg_heart_rate ?
              "#{session.avg_heart_rate} bpm" : '-' ])
      t.row([ 'Max. HR:', session.max_heart_rate ?
              "#{session.max_heart_rate} bpm" : '-' ])
      t.row([ 'Training Effect:', session.total_training_effect ?
              session.total_training_effect : '-' ])
      t.row([ 'Avg. Run Cadence:',
              session.avg_running_cadence ?
              "#{session.avg_running_cadence.round} spm" : '-' ])
      t.row([ 'Avg. Vertical Oscillation:',
              local_value(session, 'avg_vertical_oscillation', '%.1f %s',
                          { :metric => 'cm', :statute => 'in' }) ])
      t.row([ 'Avg. Ground Contact Time:',
              session.avg_stance_time ?
              "#{session.avg_stance_time.round} ms" : '-' ])
      t.row([ 'Avg. Stride Length:',
              local_value(session, 'avg_stride_length', '%.2f %s',
                          { :metric => 'm', :statute => 'ft' }) ])
      rec_time = @fit_activity.recovery_time
      t.row([ 'Recovery Time:', rec_time ? secsToHMS(rec_time * 60) : '-' ])
      vo2max = @fit_activity.vo2max
      t.row([ 'VO2max:', vo2max ? vo2max : '-' ])

      t
    end

    def laps
      session = @fit_activity.sessions[0]

      t = FlexiTable.new
      t.head
      t.row([ 'Lap', 'Duration', 'Distance',
              session.sport == 'running' ? 'Avg. Pace' : 'Avg. Speed',
              'Stride', 'Cadence', 'Avg. HR', 'Max. HR' ])
      t.set_column_attributes(Array.new(8, { :halign => :right }))
      t.body
      session.laps.each.with_index do |lap, index|
        t.cell(index + 1)
        t.cell(secsToHMS(lap.total_timer_time))
        t.cell(local_value(lap, 'total_distance', '%.2f',
                           { :metric => 'km', :statute => 'mi' }))
        if session.sport == 'running'
          t.cell(pace(lap, 'avg_speed', false))
        else
          t.cell(local_value(lap, 'avg_speed', '%.1f',
                             { :metric => 'km/h', :statute => 'mph' }))
        end
        t.cell(local_value(lap, 'avg_stride_length', '%.2f',
                           { :metric => 'm', :statute => 'ft' }))
        t.cell(lap.avg_running_cadence && lap.avg_fractional_cadence ?
               '%.1f' % (2 * lap.avg_running_cadence +
                         (2 * lap.avg_fractional_cadence) / 100.0) : '')
        t.cell(lap.avg_heart_rate.to_s)
        t.cell(lap.max_heart_rate.to_s)
        t.new_row
      end

      t
    end

    def local_value(fdr, field, format, units)
      unit = units[@unit_system]
      value = fdr.get_as(field, unit)
      return '-' unless value
      "#{format % [value, unit]}"
    end

    def pace(fdr, field, show_unit = true)
      speed = fdr.get(field)
      case @unit_system
      when :metric
        "#{speedToPace(speed)}#{show_unit ? ' min/km' : ''}"
      when :statute
        "#{speedToPace(speed, 1609.34)}#{show_unit ? ' min/mi' : ''}"
      else
        Log.fatal "Unknown unit system #{@unit_system}"
      end
    end

  end

end

