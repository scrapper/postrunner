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

  before(:each) do
    fa = create_fit_activity('2014-08-26-19:00', 30)
    a = Activity.new(fa, 'running')
    @as = PostRunner::ActivitySummary.new(a, :metric,
                          { :name => 'test', :type => 'Running',
                            :sub_type => 'Street' })
  end

  it 'should create a metric summary' do
    puts @as.to_s #TODO: Fix aggregation first
  end

end

