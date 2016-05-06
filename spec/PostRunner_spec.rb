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

require 'fileutils'

require 'spec_helper'
require 'postrunner/Main'

describe PostRunner::Main do

  def postrunner(args)
    args = [ '--dbdir', @db_dir ] + args
    begin
      old_stdout = $stdout
      old_stderr = $stderr
      $stdout = (stdout = StringIO.new)
      $stderr = (stderr = StringIO.new)
      GC.start
      retval = PostRunner::Main.new.main(args)
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
    end

    { :retval => retval, :stdout => stdout.string, :stderr => stderr.string }
  end

  before(:all) do
    capture_stdio
    create_working_dirs

    @db_dir = File.join(@work_dir, '.postrunner')
    @opts = { :t => '2014-07-01-8:00', :speed => 11.0 }
    @file1 = create_fit_activity_file(@work_dir, @opts)
    @opts[:t] = '2014-07-02-8:00'
    @file2 = create_fit_activity_file(@work_dir, @opts)
    @opts[:t] = '2014-07-03-8:00'
    @opts[:speed] = 12.5
    @file3 = create_fit_activity_file(@work_dir, @opts)
  end

  after(:all) do
    cleanup
  end

  it 'should abort without arguments' do
    v = postrunner([])
    expect(v[:retval]).to eql(-1)
  end

  it 'should abort with bad command' do
    v = postrunner(%w( foobar))
    expect(v[:retval]).to eql(-1)
  end

  it 'should support the -v option' do
    postrunner(%w( --version ))
  end

  it 'should check a FIT file' do
    postrunner([ 'check', @file1 ])
  end

  it 'should list and empty archive' do
    postrunner(%w( list ))
  end

  it 'should import a FIT file' do
    postrunner([ 'import', @file1 ])
  end

  it 'should check the imported file' do
    postrunner(%w( check :1 ))
  end

  it 'should check a FIT file' do
    postrunner([ 'check', @file2 ])
  end

  it 'should list the imported file' do
    v = postrunner(%w( list ))
    expect(v[:stdout].index(File.basename(@file1))).to be_a(Fixnum)
  end

  it 'should import the 2nd FIT file' do
    postrunner([ 'import', @file2 ])
    v = postrunner(%w( list ))
    list = v[:stdout]
    expect(list.index(File.basename(@file1))).to be_a(Fixnum)
    expect(list.index(File.basename(@file2))).to be_a(Fixnum)
  end

  it 'should delete the first file' do
    postrunner(%w( delete :2 ))
    v = postrunner(%w( list ))
    list = v[:stdout]
    expect(list.index(File.basename(@file1))).to be_nil
    expect(list.index(File.basename(@file2))).to be_a(Fixnum)
  end

  it 'should not import the deleted file again' do
    postrunner([ 'import', @file1 ])
    v = postrunner(%w( list ))
    list = v[:stdout]
    expect(list.index(File.basename(@file1))).to be_nil
    expect(list.index(File.basename(@file2))).to be_a(Fixnum)
  end

  it 'should rename FILE2.FIT activity' do
    postrunner(%w( rename foobar :1 ))
    v = postrunner(%w( list ))
    list = v[:stdout]
    expect(list.index(File.basename(@file2))).to be_nil
    expect(list.index('foobar')).to be_a(Fixnum)
  end

  it 'should fail when setting bad attribute' do
    v = postrunner(%w( set foo bar :1))
    expect(v[:retval]).to eql(-1)
  end

  it 'should set name for 2nd activity' do
    postrunner(%w( set name foobar :1 ))
    v = postrunner(%w( list ))
    list = v[:stdout]
    expect(list.index(@file2)).to be_nil
    expect(list.index('foobar')).to be_a(Fixnum)
  end

  it 'should set activity type for 2nd activity' do
    postrunner(%w( set type Cycling :1 ))
    v = postrunner(%w( summary :1 ))
    list = v[:stdout]
    expect(list.index('Running')).to be_nil
    expect(list.index('Cycling')).to be_a(Fixnum)
  end

  it 'should list the events of an activity' do
    postrunner(%w( events :1 ))
  end

  it 'should list the data sources of an activity' do
    postrunner(%w( sources :1 ))
  end

  it 'should fail when setting bad activity type' do
    v = postrunner(%w( set type foobar :1))
    expect(v[:retval]).to eql(-1)
  end

  it 'should set activity subtype for FILE2.FIT activity' do
    postrunner(%w( set subtype Road :1 ))
    v = postrunner(%w( summary :1 ))
    list = v[:stdout]
    expect(list.index('Generic')).to be_nil
    expect(list.index('Road')).to be_a(Fixnum)
  end

  it 'should fail when setting bad activity subtype' do
    v = postrunner(%w( set subtype foobar :1))
    expect(v[:retval]).to eql(-1)
  end

  it 'should dump an activity from the archive' do
    postrunner(%w( dump :1 ))
  end

  it 'should dump a FIT file' do
    postrunner([ 'dump', @file1 ])
  end

  it 'should switch to statute units' do
    postrunner(%w( units statute ))
  end

  it 'should switch back to metric units' do
    postrunner(%w( units metric ))
  end

  it 'should list records' do
    # Add slow running activity
    postrunner([ 'import', '--force', @file1 ])
    v = postrunner([ 'records' ])
    list = v[:stdout]
    expect(list.index(File.basename(@file1))).to be_a(Fixnum)

    # Add fast running activity
    postrunner([ 'import', @file3 ])
    v =postrunner([ 'records' ])
    list = v[:stdout]
    expect(list.index(File.basename(@file3))).to be_a(Fixnum)
    expect(list.index(File.basename(@file1))).to be_nil
  end

  it 'should ignore records of an activity' do
    postrunner(%w( set norecord true :1 ))
    v = postrunner([ 'records' ])
    list = v[:stdout]
    expect(list.index(File.basename(@file1))).to be_a(Fixnum)
    expect(list.index(File.basename(@file3))).to be_nil
  end

  it 'should support the daily command' do
    postrunner([ 'daily' ])
  end

  it 'should supoprt the monthly command' do
    postrunner([ 'monthly' ])
  end

end

