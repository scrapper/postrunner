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

require 'spec_helper'
require 'postrunner/ActivitySummary'

class Activity < Struct.new(:fit_activity, :sport)
end

describe PostRunner::ActivitySummary do

  before(:all) do
    capture_stdio
    create_working_dirs
    create_fit_file_store
  end

  before(:each) do
    acfg = { :t => '2014-08-26T19:00', :duration => 30, :serial => 123456790 }
    fn = create_fit_activity_file(@fit_dir, acfg)
    fa = @ffs.add_fit_file(fn)
    @as = PostRunner::ActivitySummary.new(fa, :metric,
                          { :name => 'test', :type => 'Running',
                            :sub_type => 'Street' })
  end

  after(:all) do
    cleanup
  end

  it 'should create a metric summary' do
    @as.to_s #TODO: Fix aggregation first
  end

end

