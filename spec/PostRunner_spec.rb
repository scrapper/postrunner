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
    a = Fit4Ruby::Activity.new
    a.timestamp = Time.parse(date)
    a.total_timer_time = 30 * 60
    0.upto(30) do |mins|
      r = a.new_record('record')
      r.timestamp = a.timestamp + mins * 60
      r.distance = 200.0 * mins
      r.cadence = 75

      if mins > 0 && mins % 5 == 0
        s = a.new_record('laps')
      end
    end
    a.new_record('session')
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

