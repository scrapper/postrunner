#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PostRunner_spec.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'

require 'postrunner/Main'

describe PostRunner::Main do

  def postrunner(args)
    args = [ '--dbdir', @db_dir ] + args
    old_stdout = $stdout
    $stdout = (stdout = StringIO.new)
    PostRunner::Main.new(args)
    $stdout = old_stdout
    stdout.string
  end

  def create_fit_file(name, date)
    ts = Time.parse(date)
    a = Fit4Ruby::Activity.new({ :timestamp => ts })
    a.total_timer_time = 30 * 60
    a.new_user_profile({ :timestamp => ts,
                         :age => 33, :height => 1.78, :weight => 73.0,
                         :gender => 'male', :activity_class => 4.0,
                         :max_hr => 178 })

    a.new_event({ :timestamp => ts, :event => 'timer',
                  :event_type => 'start_time' })
    a.new_device_info({ :timestamp => ts, :device_index => 0 })
    a.new_device_info({ :timestamp => ts, :device_index => 1,
                        :battery_status => 'ok' })
    0.upto(a.total_timer_time / 60) do |mins|
      ts += 60
      a.new_record({
        :timestamp => ts,
        :position_lat => 51.5512 - mins * 0.0008,
        :position_long => 11.647 + mins * 0.002,
        :distance => 200.0 * mins,
        :altitude => 100 + mins * 0.5,
        :speed => 3.1,
        :vertical_oscillation => 9 + mins * 0.02,
        :stance_time => 235.0 * mins * 0.01,
        :stance_time_percent => 32.0,
        :heart_rate => 140 + mins,
        :cadence => 75,
        :activity_type => 'running',
        :fractional_cadence => (mins % 2) / 2.0
      })

      if mins > 0 && mins % 5 == 0
        a.new_lap({ :timestamp => ts })
      end
    end
    a.new_session({ :timestamp => ts })
    a.new_event({ :timestamp => ts, :event => 'recovery_time',
                  :event_type => 'marker',
                  :data => 2160 })
    a.new_event({ :timestamp => ts, :event => 'vo2max',
                  :event_type => 'marker', :data => 52 })
    a.new_event({ :timestamp => ts, :event => 'timer',
                  :event_type => 'stop_all' })
    a.new_device_info({ :timestamp => ts, :device_index => 0 })
    ts += 1
    a.new_device_info({ :timestamp => ts, :device_index => 1,
                        :battery_status => 'low' })
    ts += 120
    a.new_event({ :timestamp => ts, :event => 'recovery_hr',
                  :event_type => 'marker', :data => 132 })

    a.aggregate
    Fit4Ruby.write(name, a)
  end

  before(:all) do
    @db_dir = File.join(File.dirname(__FILE__), '.postrunner')
    FileUtils.rm_rf(@db_dir)
    FileUtils.rm_rf('FILE1.FIT')
    create_fit_file('FILE1.FIT', '2014-07-01-8:00')
    create_fit_file('FILE2.FIT', '2014-07-02-8:00')
  end

  after(:all) do
    FileUtils.rm_rf(@db_dir)
    FileUtils.rm_rf('FILE1.FIT')
    FileUtils.rm_rf('FILE2.FIT')
  end

  it 'should abort without arguments' do
    lambda { postrunner([]) }.should raise_error SystemExit
  end

  it 'should abort with bad command' do
    lambda { postrunner(%w( foobar)) }.should raise_error SystemExit
  end

  it 'should support the -v option' do
    postrunner(%w( --version ))
  end

  it 'should check a FIT file' do
    postrunner(%w( check FILE1.FIT ))
  end

  it 'should list and empty archive' do
    postrunner(%w( list ))
  end

  it 'should import a FIT file' do
    postrunner(%w( import FILE1.FIT ))
  end

  it 'should check the imported file' do
    postrunner(%w( check :1 ))
  end

  it 'should check a FIT file' do
    postrunner(%w( check FILE2.FIT ))
  end

  it 'should list the imported file' do
    postrunner(%w( list )).index('FILE1.FIT').should be_a(Fixnum)
  end

  it 'should import another FIT file' do
    postrunner(%w( import FILE2.FIT ))
    list = postrunner(%w( list ))
    list.index('FILE1.FIT').should be_a(Fixnum)
    list.index('FILE2.FIT').should be_a(Fixnum)
  end

  it 'should delete the first file' do
    postrunner(%w( delete :2 ))
    list = postrunner(%w( list ))
    list.index('FILE1.FIT').should be_nil
    list.index('FILE2.FIT').should be_a(Fixnum)
  end

  it 'should not import the deleted file again' do
    postrunner(%w( import . ))
    list = postrunner(%w( list ))
    list.index('FILE1.FIT').should be_nil
    list.index('FILE2.FIT').should be_a(Fixnum)
  end

  it 'should rename FILE2.FIT activity' do
    postrunner(%w( rename :1 --name foobar ))
    list = postrunner(%w( list ))
    list.index('FILE2.FIT').should be_nil
    list.index('foobar').should be_a(Fixnum)
  end

  it 'should dump an activity from the archive' do
    postrunner(%w( dump :1 ))
  end

  it 'should dump a FIT file' do
    postrunner(%w( dump FILE1.FIT ))
  end

end

