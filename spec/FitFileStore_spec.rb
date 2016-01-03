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

require 'fit4ruby/FileNameCoder'
require 'postrunner/RuntimeConfig'
require 'postrunner/FitFileStore'
require 'postrunner/PersonalRecords'

describe PostRunner::FitFileStore do

  before(:all) do
    capture_stdio
    create_working_dirs
    create_fit_file_store

    # Create some test fit files
    @fit_file_names = []
    [
      { :t => '2015-10-21T21:00', :duration => 10, :serial => 123456790 },
      { :t => '2015-10-22T08:10', :duration => 15, :serial => 123456791 },
      { :t => '2015-11-01T13:30', :duration => 20, :serial => 123456790 }
    ].each do |config|
      f = create_fit_activity_file(@fit_dir, config)
      @fit_file_names << f
    end
    @activities = []
  end

  after(:all) do
    cleanup
  end

  it 'should be empty at start' do
    expect(@ffs.devices.length).to eq(0)
    expect(@ffs.activities.length).to eq(0)
  end

  it 'should store a FIT file' do
    @activities << @ffs.add_fit_file(@fit_file_names[0])
    expect(@activities[-1]).not_to be_nil

    expect(@ffs.devices.length).to eq(1)
    expect(@ffs.devices.include?('garmin-fenix3-123456790')).to be true
    expect(@ffs.activities.length).to eq(1)
    expect(@ffs.ref_by_activity(@activities[0])).to eq(1)
  end

  it 'should not store the same FIT file twice' do
    expect(@ffs.add_fit_file(@fit_file_names[0])).to be_nil

    expect(@ffs.devices.length).to eq(1)
    expect(@ffs.devices.include?('garmin-fenix3-123456790')).to be true
    expect(@ffs.activities.length).to eq(1)
  end

  it 'should store another FIT file as 2nd device' do
    @activities << @ffs.add_fit_file(@fit_file_names[1])
    expect(@activities[-1]).not_to be_nil

    expect(@ffs.devices.length).to eq(2)
    expect(@ffs.devices.include?('garmin-fenix3-123456790')).to be true
    expect(@ffs.devices.include?('garmin-fenix3-123456791')).to be true
    expect(@ffs.activities.length).to eq(2)
    expect(@ffs.ref_by_activity(@activities[1])).to eq(1)
  end

  it 'should store another activity of a known device' do
    @activities << @ffs.add_fit_file(@fit_file_names[2])
    expect(@activities[-1]).not_to be_nil

    expect(@ffs.devices.length).to eq(2)
    expect(@ffs.devices.include?('garmin-fenix3-123456790')).to be true
    expect(@ffs.devices.include?('garmin-fenix3-123456791')).to be true
    expect(@ffs.activities.length).to eq(3)
    expect(@ffs.ref_by_activity(@activities[2])).to eq(1)
  end

  it 'should find activities by index' do
    expect(@ffs.find('0')).to eq([])
    expect(@ffs.find('1')).to eq([ @activities[2] ])
    expect(@ffs.find('2')).to eq([ @activities[1] ])
    expect(@ffs.find('3')).to eq([ @activities[0] ])
    expect(@ffs.find('1-2')).to eq([ @activities[2], @activities[1] ])
    expect(@ffs.find('2-1')).to eq([])
    expect(@ffs.find('')).to eq([])
  end

  it 'should check all stored fit files' do
    @ffs.check
  end

  it 'should know the successor of each activity' do
    expect(@ffs.successor(@activities[2])).to be_nil
    expect(@ffs.successor(@activities[1])).to eq(@activities[2])
    expect(@ffs.successor(@activities[0])).to eq(@activities[1])
  end

  it 'should know the predecessor of each activity' do
    expect(@ffs.predecessor(@activities[2])).to eq(@activities[1])
    expect(@ffs.predecessor(@activities[1])).to eq(@activities[0])
    expect(@ffs.predecessor(@activities[0])).to be_nil
  end

  it 'should delete activities' do
    @ffs.delete_activity(@activities[1])
    expect(@ffs.find('1')).to eq([ @activities[2] ])
    expect(@ffs.find('2')).to eq([ @activities[0] ])
    expect(@ffs.find('3')).to eq([])

    @ffs.delete_activity(@activities[2])
    expect(@ffs.find('1')).to eq([ @activities[0] ])
    expect(@ffs.find('2')).to eq([])
  end

  it 'should rename an activity' do
    @ffs.rename_activity(@activities[0], 'new name')
    expect(@activities[0].name).to eq('new name')
    expect(@activities[0].fit_file_name).to eq(File.basename(@fit_file_names[0]))
  end

end

