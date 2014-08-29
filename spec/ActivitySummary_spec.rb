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

require 'postrunner/ActivitySummary'
require 'spec_helper'

describe PostRunner::ActivitySummary do

  before(:each) do
    @as = PostRunner::ActivitySummary.new(
      create_fit_activity('2014-08-26-19:00', 30), 'test', :metric)
  end

  it 'should create a metric summary' do
    puts @as.to_s #TODO: Fix aggregation first
  end

end

