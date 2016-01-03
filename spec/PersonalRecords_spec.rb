#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PostRunner_spec.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'spec_helper'
require 'perobs'

require 'fit4ruby/FileNameCoder'
require 'postrunner/FitFileStore'
require 'postrunner/PersonalRecords'

describe PostRunner::PersonalRecords do

  class Mock_Activity < PEROBS::Object

    po_attr :name, :fit_file_name

    def initialize(store, name = nil)
      super(store)
      init_attr(:name, name)
      init_attr(:fit_file_name, name)
    end

  end

  class Mock_FitFileStore < PEROBS::Object

    po_attr :activities

    def initialize(store)
      super
      init_attr(:activities, @store.new(PEROBS::Array))
    end

    def add_activity(a)
      @activities << a
    end

    def ref_by_activity(a)
      @activities.index(a) + 1
    end

  end

  before(:all) do
    @log = StringIO.new
    Fit4Ruby::Log.open(@log)
    @work_dir = tmp_dir_name(__FILE__)
    Dir.mkdir(@work_dir)

    # Create the FitFileStore
    @store = PEROBS::Store.new(File.join(@work_dir, 'db'))
    @store['config'] = @store.new(PEROBS::Hash)
    @store['config']['data_dir'] = @work_dir
    @ffs = @store['file_store'] = @store.new(Mock_FitFileStore)
    @records = @store['records'] = @store.new(PostRunner::PersonalRecords)
  end

  after(:all) do
    FileUtils.rm_rf(@work_dir)
  end

  it 'should initialize properly' do
    expect(@records.to_s).to eq('')
  end

  it 'should register a record' do
    a = @store.new(Mock_Activity, 'Activity 1')
    @ffs.add_activity(a)
    t = Time.parse('2014-11-08T09:16:00')
    expect(@records.register_result(a, 'running', 5000.0, 20 * 60,
                                    t)).to be true
    expect(@records.register_result(a, 'running', 5000.0, nil, t)).to be true
    expect(@records.activity_records(a).length).to eq(4)
    expect(tables_to_arrays(@records.to_s)).to eq([
      [["5 km", "0:20:00", "4:00", "1", "Activity 1", "2014-11-08"],
       ["Longest Distance", "5.000 km", "-", "1", "Activity 1", "2014-11-08"]],
      [["5 km", "0:20:00", "4:00", "1", "Activity 1", "2014-11-08"],
       ["Longest Distance", "5.000 km", "-", "1", "Activity 1", "2014-11-08"]]
    ])
  end

  it 'should register another record' do
    a = @store.new(Mock_Activity, 'Activity 2')
    @ffs.add_activity(a)
    t = Time.parse('2014-11-09T09:16:00')
    expect(@records.register_result(a, 'running', 10000.0,
                                    42 * 60, t)).to be true
    expect(@records.register_result(a, 'running', 10000.0,
                                    nil, t)).to be true
    expect(@records.activity_records(a).length).to eq(4)
    expect(tables_to_arrays(@records.to_s)).to eq([
      [["5 km", "0:20:00", "4:00", "1", "Activity 1", "2014-11-08"],
       ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
      [["5 km", "0:20:00", "4:00", "1", "Activity 1", "2014-11-08"],
       ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
    ])
  end

  it 'should replace an old record with a new one' do
    a = @store.new(Mock_Activity, 'Activity 3')
    @ffs.add_activity(a)
    t = Time.parse('2014-11-11T09:16:00')
    expect(@records.register_result(a, 'running', 5000.0,
                                    19 * 60, t)).to be true
    expect(@records.activity_records(a).length).to eq (2)
    expect(@records.activity_records(@ffs.activities[0]).length).to eq(0)
    expect(tables_to_arrays(@records.to_s)).to eq([
      [["5 km", "0:19:00", "3:47", "3", "Activity 3", "2014-11-11"],
       ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
      [["5 km", "0:19:00", "3:47", "3", "Activity 3", "2014-11-11"],
       ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
    ])
  end

  it 'should add a new table for a new year' do
    a = @store.new(Mock_Activity, 'Activity 4')
    @ffs.add_activity(a)
    t = Time.parse('2015-01-01T06:00:00')
    expect(@records.register_result(a, 'running', 5000.0,
                                    21 * 60, t)).to be true
    expect(@records.activity_records(a).length).to eq(1)
    expect(tables_to_arrays(@records.to_s)).to eq([
      [["5 km", "0:19:00", "3:47", "3", "Activity 3", "2014-11-11"],
       ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
      [["5 km", "0:21:00", "4:12", "4", "Activity 4", "2015-01-01"]],
      [["5 km", "0:19:00", "3:47", "3", "Activity 3", "2014-11-11"],
       ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
    ])
  end

  it 'should not add a new record for poor result' do
    a = @store.new(Mock_Activity, 'Activity 5')
    @ffs.add_activity(a)
    t = Time.parse('2015-01-02T10:00:00')
    expect(@records.register_result(a, 'running', 5000.0, 22 * 60,
                                    t)).to be false
    expect(@records.activity_records(a).length).to eq(0)
  end

  it 'should not delete a record for non-record activity' do
    expect(@records.delete_activity(@ffs.activities[0])).to be false
  end

  it 'should delete a record for a record activity' do
    expect(@records.delete_activity(@ffs.activities[2])).to be true
    expect(tables_to_arrays(@records.to_s)).to eq([
      [["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
      [["5 km", "0:21:00", "4:12", "4", "Activity 4", "2015-01-01"]],
      [["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
    ])
  end

  it 'should add a new distance record' do
    a = @store.new(Mock_Activity, 'Activity 6')
    @ffs.add_activity(a)
    t = Time.parse('2015-01-10T07:00:00')
    expect(@records.register_result(a, 'running', 15000.0, nil, t)).to be true
    expect(@records.activity_records(a).length).to eq(2)
    expect(tables_to_arrays(@records.to_s)).to eq([
      [ ["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "15.000 km", "-", "6", "Activity 6", "2015-01-10"]],
      [["5 km", "0:21:00", "4:12", "4", "Activity 4", "2015-01-01"],
       ["Longest Distance", "15.000 km", "-", "6", "Activity 6", "2015-01-10"]],
      [["10 km", "0:42:00", "4:12", "2", "Activity 2", "2014-11-09"],
       ["Longest Distance", "10.000 km", "-", "2", "Activity 2", "2014-11-09"]],
    ])
  end

  it 'should not register a record for a bogus sport' do
    a = @store.new(Mock_Activity, 'Activity 5')
    @ffs.add_activity(a)
    t = Time.parse('2015-04-01T11:11:11')
    expect(@records.register_result(a, 'foobaring', 5000.0, 10 * 60,
                                    t)).to be false
  end

  it 'should not register a record for unknown distance' do
    a = @store.new(Mock_Activity, 'Activity 6')
    @ffs.add_activity(a)
    expect { @records.register_result(a, 'cycling', 42.0, 10 * 60,
             Time.parse('2015-04-01T11:11:11'))}.to raise_error(Fit4Ruby::Error)
  end

  it 'should delete all records' do
    @records.delete_all_records
    expect(@records.to_s).to eq('')
  end

end
