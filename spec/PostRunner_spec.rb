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

require 'spec_helper'
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
    FileUtils::rm_rf('icons')
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

  it 'should import the other FIT file' do
    postrunner([ 'import', '.' ])
    list = postrunner(%w( list ))
    list.index('FILE1.FIT').should be_a(Fixnum)
    list.index('FILE2.FIT').should be_a(Fixnum)
    rc = YAML::load_file(File.join(@db_dir, 'config.yml'))
    rc[:import_dir].should == '.'

    template = "<a href=\"%s.html\"><img src=\"icons/%s.png\" " +
               "class=\"active_button\">"
    html1 = File.read(File.join(@db_dir, 'html', 'FILE1.html'))
    html1.include?(template % ['FILE2', 'forward']).should be_true
    html2 = File.read(File.join(@db_dir, 'html', 'FILE2.html'))
    html2.include?(template % ['FILE1', 'back']).should be_true
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
    postrunner(%w( rename foobar :1 ))
    list = postrunner(%w( list ))
    list.index('FILE2.FIT').should be_nil
    list.index('foobar').should be_a(Fixnum)
  end

  it 'should fail when setting bad attribute' do
    lambda { postrunner(%w( set foo bar :1)) }.should raise_error SystemExit
  end

  it 'should set name for FILE2.FIT activity' do
    postrunner(%w( set name foobar :1 ))
    list = postrunner(%w( list ))
    list.index('FILE2.FIT').should be_nil
    list.index('foobar').should be_a(Fixnum)
  end

  it 'should set activity type for FILE2.FIT activity' do
    postrunner(%w( set type Cycling :1 ))
    list = postrunner(%w( summary :1 ))
    list.index('Running').should be_nil
    list.index('Cycling').should be_a(Fixnum)
  end

  it 'should fail when setting bad activity type' do
    lambda { postrunner(%w( set type foobar :1)) }.should raise_error SystemExit
  end

  it 'should set activity subtype for FILE2.FIT activity' do
    postrunner(%w( set subtype Road :1 ))
    list = postrunner(%w( summary :1 ))
    list.index('Generic').should be_nil
    list.index('Road').should be_a(Fixnum)
  end

  it 'should fail when setting bad activity subtype' do
    lambda { postrunner(%w( set subtype foobar :1)) }.should raise_error SystemExit
  end

  it 'should dump an activity from the archive' do
    postrunner(%w( dump :1 ))
  end

  it 'should dump a FIT file' do
    postrunner(%w( dump FILE1.FIT ))
  end

  it 'should switch to statute units' do
    postrunner(%w( units statute ))
  end

  it 'should switch back to metric units' do
    postrunner(%w( units metric ))
  end

  it 'should properly upgrade to a new version' do
    # Change version in config file to 0.0.0.
    rc = PostRunner::RuntimeConfig.new(@db_dir)
    rc.set_option(:version, '0.0.0')
    # Check that the config file really was changed.
    rc = PostRunner::RuntimeConfig.new(@db_dir)
    rc.get_option(:version).should == '0.0.0'

    archive_file = File.join(@db_dir, 'archive.yml')
    archive = YAML.load_file(archive_file)
    archive.each { |a| a.remove_instance_variable:@sport }
    File.write(archive_file, archive.to_yaml)

    # Run some command.
    postrunner(%w( list ))

    # Check that version matches the current version again.
    rc = PostRunner::RuntimeConfig.new(@db_dir)
    rc.get_option(:version).should == PostRunner::VERSION
  end

end

