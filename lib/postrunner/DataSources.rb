#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DataSources.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
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

  # The DataSources objects can generate a table that lists all the data
  # sources in chronological order that were in use during a workout.
  class DataSources

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

    def to_s
      data_sources.to_s
    end

    def to_html(doc)
      ViewFrame.new('data_sources', "Data Sources", 1210, data_sources,
                    true).to_html(doc)
    end

    private

    def data_sources
      session = @fit_activity.sessions[0]

      t = FlexiTable.new
      t.enable_frame(false)
      t.body
      t.row([ 'Time', 'Distance', 'Mode', 'Distance', 'Speed',
              'Cadence', 'Elevation', 'Heart Rate', 'Power', 'Calories'  ])
      start_time = session.start_time
      @fit_activity.data_sources.each do |source|
        t.cell(secsToHMS(source.timestamp - start_time))
        t.cell(@activity.distance(source.timestamp, @unit_system))
        t.cell(source.mode)
        t.cell(device_name(source.distance))
        t.cell(device_name(source.speed))
        t.cell(device_name(source.cadence))
        t.cell(device_name(source.elevation))
        t.cell(device_name(source.heart_rate))
        t.cell(device_name(source.power))
        t.cell(device_name(source.calories))
        t.new_row
      end

      t
    end

    def device_name(index)
      @fit_activity.device_infos.each do |device|
        if device.device_index == index
          return (DeviceList::DeviceTypeNames[device.device_type] ||
                  device.device_type) + " [#{device.device_index}]"
        end
      end

      ''
    end

  end

end

