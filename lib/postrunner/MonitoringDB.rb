#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MonitoringDB.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/TimestampedObjectList'
require 'postrunner/MonitoringData'

module PostRunner

  class MonitoringDB

    def initialize(store, cfg)
      @store = store
      @tol = TimestampedObjectList.new(@store, 'monitoring')
    end

    def add(fit_file_name, fit_monitoring_b)
      start_time = fit_monitoring_b.monitoring_infos[0].timestamp
      data = MonitoringData.new(@store)
      @tol.add_object(start_time, data)

      fit_monitoring_b.monitorings.each do |monitoring|
        if (cati = monitoring.current_activity_type_intensity)
          data = MonitoringData.new(@store)
          @tol.add_object(monitoring.timestamp, data)
          data.activity_type = decode_activity_type(cati & 0x1F)
          data.intensity = (cati >> 5) & 0x7
          #puts "#{monitoring.timestamp}: #{decode_activity_type(cati & 0x1F)}" +
          #     "  #{(cati >> 5) & 0x7}"
        end
      end
    end

    private

    def decode_activity_type(activity_type)
      types = [ :generic, :running, :cycling, :transition,
                :fitness_equipment, :swimming, :walking, :unknown7,
                :resting, :unknown9 ]
      if (decoded_type = types[activity_type])
        decoded_type
      else
        Log.error "Unknown activity type #{activity_type}"
        :generic
      end
    end

  end

end
