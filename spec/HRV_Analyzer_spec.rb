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

describe PostRunner::HRV_Analyzer do

  it 'should cleanup the input data' do
    rri = [ 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.5, 0.3,
            0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
            0.3, 0.3, 0.1, 0.3, 0.3, 0.3, 0.3, 0.4,
            0.5, 0.3, 0.3, 0.2, 0.3, 0.3, 0.3, 0.3 ]
    hrv = PostRunner::HRV_Analyzer.new(rri)
    rro = [ 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, nil, 0.3,
            0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3,
            0.3, 0.3, 0.1, 0.3, 0.3, 0.3, 0.3, 0.4,
            nil, 0.3, 0.3, 0.2, 0.3, 0.3, 0.3, 0.3 ]
    expect(hrv.rr_intervals).to eql(rro)
    expect(hrv.errors).to eql(2)
    ts = [ 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.3, 2.6,
           2.9, 3.2, 3.5, 3.8, 4.1, 4.4, 4.7, 5.0,
           5.3, 5.6, 5.7, 6.0, 6.3, 6.6, 6.9, 7.3,
           7.8, 8.1, 8.4, 8.6, 8.9, 9.2, 9.5, 9.8 ]
    hrv.timestamps.each_with_index do |v, i|
      expect(v).to be_within(0.01).of(ts[i])
    end
    expect(hrv.has_hrv_data?).to be false
    expect(hrv.rmssd).to be_within(0.01).of(63.828)
  end

  it 'should compute an HRV Score' do
    rri =[
      0.834, 0.794, 0.789, 0.792, 0.8, 0.795, 0.789, 0.785, 0.783,
      0.778, 0.737, 0.711, 0.705, 0.717, 0.755, 0.827, 0.885, 0.888, 0.86,
      0.832, 0.808, 0.755, 0.722, 0.708, 0.693, 0.728, 0.767, 0.838, 0.875,
      0.888, 0.865, 0.797, 0.75, 0.729, 0.708, 0.733, 0.754, 0.791, 0.803,
      0.788, 0.76, 0.732, 0.748, 0.754, 0.781, 0.794, 0.787, 0.779, 0.744,
      0.716, 0.703, 0.7, 0.731, 0.808, 0.793, 0.787, 0.74, 0.716, 0.720,
      0.724, 0.76, 0.785, 0.817, 0.793, 0.76, 0.741, 0.733, 0.754, 0.785,
      0.813, 0.833, 0.814, 0.794, 0.78, 0.775
    ]
    hrv = PostRunner::HRV_Analyzer.new(rri)
    expect(hrv.rmssd).to be_within(0.00001).of(29.59341)
    expect(hrv.ln_rmssd).to be_within(0.00001).of(3.38755)
    expect(hrv.hrv_score).to be_within(0.00001).of(32.50346)
  end

  it 'should find the right interval for a HRV score computation' do
    rri =[
      0.999, 0.989, 0.998, 0.989, 0.997, 0.989, 0.999, 0.997, 0.999,
      0.834, 0.794, 0.789, 0.792, 0.8, 0.795, 0.789, 0.785, 0.783,
      0.778, 0.737, 0.711, 0.705, 0.717, 0.755, 0.827, 0.885, 0.888, 0.86,
      0.832, 0.808, 0.755, 0.722, 0.708, 0.693, 0.728, 0.767, 0.838, 0.875,
      0.888, 0.865, 0.797, 0.75, 0.729, 0.708, 0.733, 0.754, 0.791, 0.803,
      0.788, 0.76, 0.732, 0.748, 0.754, 0.781, 0.794, 0.787, 0.779, 0.744,
      0.716, 0.703, 0.7, 0.731, 0.808, 0.793, 0.787, 0.74, 0.716, 0.720,
      0.724, 0.76, 0.785, 0.817, 0.793, 0.76, 0.741, 0.733, 0.754, 0.785,
      0.813, 0.833, 0.814, 0.794, 0.78, 0.775,
      0.997, 0.989, 0.999, 0.998, 0.999, 0.997
    ]
    hrv = PostRunner::HRV_Analyzer.new(rri)
    expect(hrv.one_sigma(:hrv_score)).to be_within(0.00001).of(32.12369)
  end

end

