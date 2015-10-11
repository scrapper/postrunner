#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = spec_helper.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# Some dependencies may not be installed as Ruby Gems but as local sources.
# Add them and the postrunner dir to the LOAD_PATH.
%w( postrunner fit4ruby perobs ).each do |lib_dir|
  $:.unshift(File.join(File.dirname(__FILE__), '..', '..', lib_dir, 'lib'))
end

def create_fit_file(name, date, duration_minutes = 30)
  Fit4Ruby.write(name, create_fit_activity(date, duration_minutes))
end

def create_fit_activity(date, duration_minutes)
  ts = Time.parse(date)
  a = Fit4Ruby::Activity.new({ :timestamp => ts })
  a.total_timer_time = duration_minutes * 60
  a.new_user_profile({ :timestamp => ts,
                       :age => 33, :height => 1.78, :weight => 73.0,
                       :gender => 'male', :activity_class => 7.0,
                       :max_hr => 178 })

  a.new_event({ :timestamp => ts, :event => 'timer',
                :event_type => 'start_time' })
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :device_index => 0 })
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :device_index => 1, :battery_status => 'ok' })
  0.upto((a.total_timer_time / 60) - 1) do |mins|
    a.new_record({
      :timestamp => ts,
      :position_lat => 51.5512 - mins * 0.0008,
      :position_long => 11.647 + mins * 0.002,
      :distance => 200.0 * mins,
      :altitude => 100 + mins * 3,
      :speed => 3.1,
      :vertical_oscillation => 90 + mins * 0.2,
      :stance_time => 235.0 * mins * 0.01,
      :stance_time_percent => 32.0,
      :heart_rate => 140 + mins,
      :cadence => 75,
      :activity_type => 'running',
      :fractional_cadence => (mins % 2) / 2.0
    })

    if mins > 0 && mins % 5 == 0
      a.new_lap({ :timestamp => ts, :sport => 'running' })
    end
    ts += 60
  end
  a.new_session({ :timestamp => ts, :sport => 'running' })
  a.new_event({ :timestamp => ts, :event => 'recovery_time',
                :event_type => 'marker',
                :data => 2160 })
  a.new_event({ :timestamp => ts, :event => 'vo2max',
                :event_type => 'marker', :data => 52 })
  a.new_event({ :timestamp => ts, :event => 'timer',
                :event_type => 'stop_all' })
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :device_index => 0 })
  ts += 1
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :device_index => 1, :battery_status => 'low' })
  ts += 120
  a.new_event({ :timestamp => ts, :event => 'recovery_hr',
                :event_type => 'marker', :data => 132 })

  a.aggregate

  a
end


