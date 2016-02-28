#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = EventList.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/FlexiTable'
require 'postrunner/ViewFrame'
require 'postrunner/DeviceList'

module PostRunner

  # The EventList objects can generate a table that lists all the recorded
  # FIT file events in chronological order.
  class EventList

    include Fit4Ruby::Converters

    # Create a DataSources object.
    # @param activity [Activity] The activity to analyze.
    # @param unit_system [Symbol] The unit system to use (:metric or
    #        :imperial )
    def initialize(activity, unit_system)
      @activity = activity
      @fit_activity = activity.fit_activity
      @unit_system = unit_system
    end

    # Return the list as ASCII table
    def to_s
      list.to_s
    end

    # Add the list as HTML table to the specified doc.
    # @param doc [HTMLBuilder] HTML document
    def to_html(doc)
      ViewFrame.new('events', 'Events', 600, list, true).to_html(doc)
    end

    private

    def list
      session = @fit_activity.sessions[0]

      t = FlexiTable.new
      t.enable_frame(false)
      t.body
      t.row([ 'Time', 'Distance', 'Description', 'Value' ])
      t.set_column_attributes([
        { :halign => :right },
        { :halign => :right },
        { :halign => :left },
        { :halign => :right }
      ])
      start_time = session.start_time
      @fit_activity.events.each do |event|
        t.cell(secsToHMS(event.timestamp - start_time))
        t.cell(@activity.distance(event.timestamp, @unit_system))
        event_name_and_value(t, event)
        t.new_row
      end

      t
    end

    def event_name_and_value(table, event)
      case event.event
      when 'timer'
        name = "Timer (#{event.event_type.gsub(/_/, ' ')})"
        value = event.timer_trigger
      when 'course_point'
        name = 'Course Point'
        value = event.message_index
      when 'battery'
        name = 'Battery Level'
        value = "#{event.battery_level} V"
      when 'hr_high_alert'
        name = 'HR high alert'
        value = "#{event.hr_high_alert} bpm"
      when 'hr_low_alert'
        name = 'HR low alert'
        value = "#{event.hr_low_alert} bpm"
      when 'speed_high_alert'
        name = 'Speed high alert'
        value = event.speed_high_alert
      when 'speed_low_alert'
        name = 'Speed low alert'
        value = event.speed_low_alert
      when 'cad_high_alert'
        name = 'Cadence high alert'
        value = "#{event.cad_high_alert} spm"
      when 'cad_low_alert'
        name = 'Cadence low alert'
        value = "#{event.cad_low_alert} spm"
      when 'power_high_alert'
        name = 'Power high alert'
        value = event.power_high_alert
      when 'power_low_alert'
        name = 'Power low alert'
        value = event.power_low_alert
      when 'time_duration_alert'
        name = 'Time duration alert'
        value = event.time_duration_alert
      when 'calorie_duration_alert'
        name = 'Calorie duration alert'
        value = event.calorie_duration_alert
      when 'fitness_equipment'
        name = 'Fitness equipment state'
        value = event.fitness_equipment_state
      when 'rider_position'
        name 'Rider position changed'
        value = event.rider_position
      when 'comm_timeout'
        name 'Communication timeout'
        value = event.comm_timeout
      when 'recovery_hr'
        name = 'Recovery heart rate'
        value = "#{event.recovery_hr} bpm"
      when 'recovery_time'
        name = 'Recovery time'
        value = "#{secsToDHMS(event.recovery_time * 60)}"
      when 'recovery_info'
        name = 'Recovery info'
        mins = event.recovery_info
        value = "#{secsToDHMS(mins * 60)} (#{mins < 24 * 60 ? 'Good' : 'Poor'})"
      when 'vo2max'
        name = 'VO2Max'
        value = event.vo2max
      else
        name = event.event
        value = event.data
      end

      table.cell(name)
      table.cell(value)
    end

  end

end

