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
require 'postrunner/ViewFrame'
require 'postrunner/HRV_Analyzer'
require 'postrunner/Percentiles'

module PostRunner

  class ActivitySummary

    include Fit4Ruby::Converters

    def initialize(activity, unit_system, custom_fields)
      @activity = activity
      @fit_activity = activity.fit_activity
      @name = custom_fields[:name]
      @type = custom_fields[:type]
      @sub_type = custom_fields[:sub_type]
      @unit_system = unit_system
    end

    def to_s
      summary.to_s + "\n" +
      (@activity.note ? note.to_s + "\n" : '') +
      laps.to_s
    end

    def to_html(doc)
      width = 600
      ViewFrame.new('activity', "Activity: #{@name}",
                    width, summary).to_html(doc)
      ViewFrame.new('note', 'Note', width, note,
                    true).to_html(doc) if @activity.note
      ViewFrame.new('laps', 'Laps', width, laps, true).to_html(doc)
    end

    private

    def note
      t = FlexiTable.new
      t.enable_frame(false)
      t.body
      t.row([ @activity.note ])
      t
    end

    def summary
      session = @fit_activity.sessions[0]

      t = FlexiTable.new
      t.enable_frame(false)
      t.body
      t.row([ 'Type:', @type ])
      t.row([ 'Sub Type:', @sub_type ])
      t.row([ 'Date:', session.timestamp ])
      t.row([ 'Distance:',
              local_value(session, 'total_distance', '%.2f %s',
                          { :metric => 'km', :statute => 'mi'}) ])
      if session.has_geo_data?
        t.row([ 'GPS Data based Distance:',
                local_value(@fit_activity, 'total_gps_distance', '%.2f %s',
                            { :metric => 'km', :statute => 'mi'}) ])
      end
      t.row([ 'Time:', secsToHMS(session.total_timer_time) ])
      if @activity.sport == 'running' || @activity.sport == 'multisport'
        t.row([ 'Avg. Pace:', pace(session, 'avg_speed') ])
      end
      if @activity.sport != 'running'
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
      if @activity.sport == 'running' || @activity.sport == 'multisport'
        t.row([ 'Avg. Run Cadence:',
                session.avg_running_cadence ?
                "#{(2 * session.avg_running_cadence).round} spm" : '-' ])
        t.row([ 'Avg. Stride Length:',
                local_value(session, 'avg_stride_length', '%.2f %s',
                            { :metric => 'm', :statute => 'ft' }) ])
        t.row([ 'Avg. Vertical Oscillation:',
                local_value(session, 'avg_vertical_oscillation', '%.1f %s',
                            { :metric => 'cm', :statute => 'in' }) ])
        t.row([ 'Vertical Ratio:',
                session.vertical_ratio ?
                "#{session.vertical_ratio}%" : '-' ])
        t.row([ 'Avg. Ground Contact Time:',
                session.avg_stance_time ?
                "#{session.avg_stance_time.round} ms" : '-' ])
        t.row([ 'Avg. Ground Contact Time Balance:',
                session.avg_gct_balance ?
                "#{session.avg_gct_balance}% L / " +
                "#{100.0 - session.avg_gct_balance}% R" : ';' ])
      end
      if @activity.sport == 'cycling'
        t.row([ 'Avg. Cadence:',
                session.avg_candence ?
                "#{(2 * session.avg_candence).round} rpm" : '-' ])
      end

      t.row([ 'Training Effect:', session.total_training_effect ?
              session.total_training_effect : '-' ])

      rec_info = @fit_activity.recovery_info
      t.row([ 'Ignored Recovery Time:',
              rec_info ? secsToDHMS(rec_info * 60) : '-' ])

      rec_hr = @fit_activity.recovery_hr
      end_hr = @fit_activity.ending_hr
      t.row([ 'Recovery HR:',
              rec_hr && end_hr ?
              "#{rec_hr} bpm [#{end_hr - rec_hr} bpm]" : '-' ])

      rec_time = @fit_activity.recovery_time
      t.row([ 'Suggested Recovery Time:',
              rec_time ? secsToDHMS(rec_time * 60) : '-' ])

      hrv = HRV_Analyzer.new(@fit_activity)
      if hrv.has_hrv_data?
        t.row([ 'HRV Score:', "%.1f" % hrv.lnrmssdx20_1sigma ])
      end

      t
    end

    def laps
      session = @fit_activity.sessions[0]

      t = FlexiTable.new
      t.head
      t.row([ 'Lap', 'Duration', 'Distance',
              @activity.sport == 'running' ? 'Avg. Pace' : 'Avg. Speed',
              'Stride', 'Cadence', 'Avg. HR', 'Max. HR' ])
      t.set_column_attributes(Array.new(8, { :halign => :right }))
      t.body
      session.laps.each.with_index do |lap, index|
        t.cell(index + 1)
        t.cell(secsToHMS(lap.total_timer_time))
        t.cell(local_value(lap, 'total_distance', '%.2f',
                           { :metric => 'km', :statute => 'mi' }))
        if @activity.sport == 'running'
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

