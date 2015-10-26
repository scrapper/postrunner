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

require 'tmpdir'
require 'fileutils'

# Some dependencies may not be installed as Ruby Gems but as local sources.
# Add them and the postrunner dir to the LOAD_PATH.
%w( postrunner fit4ruby perobs ).each do |lib_dir|
  $:.unshift(File.join(File.dirname(__FILE__), '..', '..', lib_dir, 'lib'))
end

def tmp_dir_name(caller_file)
  begin
    dir_name = File.join(Dir.tmpdir,
                         "#{File.basename(caller_file)}.#{rand(2**32)}")
  end while File.exists?(dir_name)

  dir_name
end

def create_fit_file(name, date, duration_minutes = 30)
  Fit4Ruby.write(name, create_fit_activity(
    { :t => date, :duration => duration_minutes }))
end

def create_fit_activity_file(dir, config)
  activity = create_fit_activity(config)
  end_time = activity.sessions[-1].start_time +
             activity.sessions[-1].total_elapsed_time
  fit_file_name = File.join(dir, Fit4Ruby::FileNameCoder.encode(end_time))
  Fit4Ruby.write(fit_file_name, activity)

  fit_file_name
end

def create_fit_activity(config)
  ts = Time.parse(config[:t])
  serial = config[:serial] || 12345890
  a = Fit4Ruby::Activity.new({ :timestamp => ts })
  a.total_timer_time = (config[:duration] || 10) * 60
  a.new_user_profile({ :timestamp => ts,
                       :age => 33, :height => 1.78, :weight => 73.0,
                       :gender => 'male', :activity_class => 7.0,
                       :max_hr => 178 })

  a.new_event({ :timestamp => ts, :event => 'timer',
                :event_type => 'start_time' })
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :garmin_product => 'fenix3',
                      :serial_number => serial,
                      :device_index => 0 })
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :garmin_product => 'sdm4',
                      :device_index => 1, :battery_status => 'ok' })
  laps = 0
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
      a.new_lap({ :timestamp => ts, :sport => 'running',
                  :message_index => laps })
      laps += 1
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
                      :garmin_product => 'fenix3',
                      :serial_number => serial,
                      :device_index => 0 })
  ts += 1
  a.new_device_info({ :timestamp => ts, :manufacturer => 'garmin',
                      :garmin_product => 'sdm4',
                      :device_index => 1, :battery_status => 'low' })
  ts += 120
  a.new_event({ :timestamp => ts, :event => 'recovery_hr',
                :event_type => 'marker', :data => 132 })

  a.aggregate

  a
end


