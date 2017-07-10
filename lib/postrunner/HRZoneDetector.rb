#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = HRZoneDetector.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2017 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  module HRZoneDetector

    # Number of heart rate zones supported by Garmin devices.
    GARMIN_ZONES = 5
    # Maximum heart rate that can be stored in FIT files.
    MAX_HR = 255

    def HRZoneDetector::detect_zones(fit_records, secs_in_zones)
      if fit_records.empty?
        raise RuntimeError, "records must not be empty"
      end
      if secs_in_zones.size != GARMIN_ZONES + 1
        raise RuntimeError, "secs_in_zones must have #{GARMIN_ZONES + 1} " +
          "elements"
      end

      # We generate a histogram of the time spent at each integer heart rate.
      histogram = Array.new(MAX_HR + 1, 0)

      last_timestamp = nil
      fit_records.each do |record|
        next unless record.heart_rate

        if last_timestamp
          # We ignore all intervals that are larger than 10 seconds. This
          # potentially conflicts with smart recording, but I can't see how a
          # larger sampling interval can yield usable results.
          if (delta_t = record.timestamp - last_timestamp) <= 10
            histogram[record.heart_rate] += delta_t
          end
        end
        last_timestamp = record.timestamp
      end

      # We'll process zones 5 downto 1.
      zone = GARMIN_ZONES
      hr_mins = Array.new(GARMIN_ZONES)
      # Sum of time spent in current zone.
      secs_in_current_zone = 0
      # We process the histogramm from highest to smallest HR value. Whenever
      # we have accumulated the provided amount of time we have found a HR
      # zone boundary. We complete the current zone and continue with the next
      # one.
      MAX_HR.downto(0) do |i|
        secs_in_current_zone += histogram[i]

        if secs_in_current_zone > secs_in_zones[zone]
          # In case we have collected more time than was specified for the
          # zone we carry the delta over to the next zone.
          secs_in_current_zone -= secs_in_zones[zone]
          # puts "Zone #{zone}: #{secs_in_current_zone}  #{secs_in_zones[zone]}"
          break if (zone -= 1) < 0
        end
        hr_mins[zone] = i
      end

      hr_mins
    end

  end

end

