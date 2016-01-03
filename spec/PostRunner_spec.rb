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
    old_stdout = $stdout
    $stdout = (stdout = StringIO.new)
    @postrunner = PostRunner::Main.new(args)
    $stdout = old_stdout
    stdout.string
  end

  before(:all) do
    capture_stdio
    create_working_dirs

    @db_dir = File.join(@work_dir, '.postrunner')
    @file1 = File.join(@work_dir, 'FILE1.FIT')
    @file2 = File.join(@work_dir, 'FILE2.FIT')
    create_fit_file(@file1, '2014-07-01-8:00')
    create_fit_file(@file2, '2014-07-02-8:00')
  end

  after(:all) do
    cleanup
  end

  it 'should abort without arguments' do
    expect { postrunner([]) }.to raise_error(Fit4Ruby::Error)
  end

  it 'should abort with bad command' do
    expect { postrunner(%w( foobar)) }.to raise_error(Fit4Ruby::Error)
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
    expect(postrunner(%w( list )).index('FILE1')).to be_a(Fixnum)
  end

  it 'should import the other FIT file' do
    postrunner([ 'import', @work_dir ])
    list = postrunner(%w( list ))
    expect(list.index('FILE1.FIT')).to be_a(Fixnum)
    expect(list.index('FILE2.FIT')).to be_a(Fixnum)
  end

  it 'should delete the first file' do
    postrunner(%w( delete :2 ))
    list = postrunner(%w( list ))
    expect(list.index('FILE1.FIT')).to be_nil
    expect(list.index('FILE2.FIT')).to be_a(Fixnum)
  end

  it 'should not import the deleted file again' do
    postrunner(%w( import . ))
    list = postrunner(%w( list ))
    expect(list.index('FILE1.FIT')).to be_nil
    expect(list.index('FILE2.FIT')).to be_a(Fixnum)
  end

  it 'should rename FILE2.FIT activity' do
    postrunner(%w( rename foobar :1 ))
    list = postrunner(%w( list ))
    expect(list.index('FILE2.FIT')).to be_nil
    expect(list.index('foobar')).to be_a(Fixnum)
  end

  it 'should fail when setting bad attribute' do
    expect { postrunner(%w( set foo bar :1)) }.to raise_error(Fit4Ruby::Error)
  end

  it 'should set name for FILE2.FIT activity' do
    postrunner(%w( set name foobar :1 ))
    list = postrunner(%w( list ))
    expect(list.index(@file2)).to be_nil
    expect(list.index('foobar')).to be_a(Fixnum)
  end

  it 'should set activity type for FILE2.FIT activity' do
    postrunner(%w( set type Cycling :1 ))
    list = postrunner(%w( summary :1 ))
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
    expect { postrunner(%w( set type foobar :1)) }.to raise_error(Fit4Ruby::Error)
  end

  it 'should set activity subtype for FILE2.FIT activity' do
    postrunner(%w( set subtype Road :1 ))
    list = postrunner(%w( summary :1 ))
    expect(list.index('Generic')).to be_nil
    expect(list.index('Road')).to be_a(Fixnum)
  end

  it 'should fail when setting bad activity subtype' do
    expect { postrunner(%w( set subtype foobar :1)) }.to raise_error(Fit4Ruby::Error)
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

end

