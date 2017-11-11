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
    rri = [ 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 1.1, 0.6,
            0.6, 0.8, 0.6, 0.61, 0.59, 0.6, 0.6, 0.6,
            0.6, 0.6, 0.2, 0.6, 0.6, 0.6, 0.6, 0.5,
            0.6, 0.6, 0.6, 1.3, 0.6, 0.6, 0.6, 0.6 ]
    hrv = PostRunner::HRV_Analyzer.new(rri)
    expect(hrv.errors).to eql(2)
    ts = [ 0.0, 0.6, 1.2, 1.8, 2.4, 3.0, 3.6, 4.7,
           5.3, 5.9, 6.7, 7.3, 7.9, 8.5, 9.1, 9.7,
           10.3, 10.9, 11.5, 11.7, 12.3, 12.9, 13.5, 14.1,
           14.6, 15.2, 15.8, 16.4, 17.7, 18.3, 18.9, 19.5 ]
    hrv.timestamps.each_with_index do |v, i|
      expect(v).to be_within(0.01).of(ts[i])
    end
    expect(hrv.has_hrv_data?).to be false
    expect(hrv.rmssd).to be_within(0.00001).of(124.81096817899)
  end

  it 'should compute an HRV Score' do
    rri = [
      0.837, 0.831, 0.843, 0.867, 0.788, 0.984, 0.872, 0.891, 0.878, 0.864,
      0.844, 0.818, 0.798, 0.791, 0.808, 0.866, 0.927, 0.951, 0.958, 0.943,
      0.613, 1.2, 0.884, 0.884, 0.878, 0.873, 0.867, 0.875, 0.872, 0.871,
      0.892, 0.943, 1.185, 0.788, 1.255, 0.636, 0.901, 0.896, 0.9, 0.915,
      0.698, 1.148, 0.894, 0.872, 0.85, 0.86, 0.893, 0.941, 0.692, 1.233,
      0.981, 0.926, 0.93, 0.928, 0.928, 0.93, 1.158, 0.68, 0.877, 0.915,
      0.926, 0.933, 0.933, 0.924, 0.681, 1.133, 0.901, 0.892, 0.887, 0.877,
      0.732, 0.968, 0.826, 0.824, 0.865, 0.905, 0.915, 0.935, 0.932, 0.924,
      0.915, 0.945, 0.96, 0.963, 0.939, 0.92, 0.892, 0.669, 1.037, 0.806,
      0.818, 0.847, 0.879, 0.922, 0.938, 0.952, 0.969, 1.018, 1.03, 1.004,
      0.98, 0.948, 0.919, 0.894, 0.896, 0.905, 0.913, 0.925, 0.905, 0.879,
      0.855, 0.857, 0.866, 0.878, 0.881, 0.884, 0.873, 0.857, 0.851, 0.864,
      0.883, 0.895, 0.898, 0.898, 0.876, 0.853, 0.841, 0.85, 0.857, 0.852,
      0.861, 0.867, 0.869, 0.858, 0.844, 0.856, 0.869, 0.879, 0.886, 0.89,
      0.876, 0.857, 0.843, 0.839, 0.838, 0.843, 0.845, 0.856, 0.856, 0.85,
      0.838, 0.842, 0.844, 0.842, 0.834, 0.832, 0.818, 0.81, 0.801, 0.78,
      0.797, 0.816, 0.838, 0.85, 0.845, 0.841, 0.84, 0.837, 0.859, 0.874,
      0.89, 0.896, 0.893, 0.879, 0.863, 0.855, 0.87, 0.875, 0.861, 0.854,
      0.843, 0.836, 0.822, 0.813, 0.806, 0.81, 0.824, 0.834, 0.847, 0.867,
      0.877, 0.883, 0.877, 0.856, 0.872, 0.88, 0.87, 0.861, 0.855, 0.852,
      0.84, 0.832, 0.82, 0.827, 0.838, 0.854, 0.881, 0.893, 0.857
    ]

    hrv = PostRunner::HRV_Analyzer.new(rri)
    expect(hrv.data_quality).to be_within(0.00001).of(100)
    expect(hrv.ln_rmssd(0.0, 90)).to be_within(0.00001).of(5.188390931)
    expect(hrv.ln_rmssd(90, 90)).to be_within(0.00001).of(2.549616730)
    expect(hrv.rmssd(0.0, 90)).to be_within(0.00001).of(179.1800079)
    expect(hrv.hrv_score(0.0, 60)).to be_within(0.00001).of(100.0)
  end

  it 'should find the right interval for a HRV score computation' do
    rri = [
      0.752, 0.759, 0.755, 0.741, 0.733, 0.738, 0.751, 0.767, 0.774, 0.777,
      0.771, 0.787, 0.795, 0.805, 0.797, 0.78, 0.77, 0.764, 0.766, 0.771,
      0.764, 0.763, 0.776, 0.777, 0.785, 0.78, 0.768, 0.757, 0.745, 0.737,
      0.724, 0.709, 0.695, 0.699, 0.703, 0.719, 0.726, 0.73, 0.733, 0.739,
      0.744, 0.744, 0.738, 0.725, 0.713, 0.706, 0.705, 0.7, 0.694, 0.697,
      0.706, 0.716, 0.728, 0.73, 0.731, 0.742, 0.748, 0.742, 0.733, 0.731,
      0.729, 0.727, 0.712, 0.712, 0.715, 0.712, 0.706, 0.707, 0.729, 0.762,
      0.773, 0.768, 0.78, 0.78, 0.771, 0.75, 0.736, 0.719, 0.704, 0.69, 0.683,
      0.688, 0.703, 0.732, 0.742, 0.751, 0.758, 0.783, 0.786, 0.764, 0.752,
      0.733, 0.722, 0.711, 0.694, 0.687, 0.69, 0.707, 0.722, 0.732, 0.761,
      0.783, 0.805, 0.795, 0.779, 0.76, 0.744, 0.726, 0.707, 0.692, 0.688,
      0.694, 0.695, 0.708, 0.729, 0.761, 0.776, 0.787, 0.799, 0.795, 0.773,
      0.755, 0.738, 0.721, 0.71, 0.701, 0.692, 0.698, 0.712, 0.73, 0.736,
      0.732, 0.722, 0.72, 0.712, 0.709, 0.695, 0.687, 0.688, 0.684, 0.687,
      0.685, 0.685, 0.684, 0.689, 0.705, 0.716, 0.712, 0.71, 0.732, 0.75,
      0.755, 0.757, 0.758, 0.759, 0.753, 0.748, 0.748, 0.724, 0.715, 0.721,
      0.727, 0.743, 0.741, 0.743, 0.757, 0.765, 0.774, 0.781, 0.77, 0.745,
      0.729, 0.707
    ]
    hrv = PostRunner::HRV_Analyzer.new(rri)
    expect(hrv.hrv_score).to be_within(0.00001).of(0.0)
  end

end

