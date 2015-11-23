#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Percentiles.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # This class can be used to partition sets according to a given percentile.
  class Percentiles

    # Create a Percentiles object for the given data set.
    # @param set [Array] It must be an Array of tuples (2 element Array). The
    #        first element is the actual value, the second does not matter for
    #        the computation. It is usually a reference to the context of the
    #        value.
    def initialize(set)
      @set = set.sort { |e1, e2| e1[0] <=> e2[0] }
    end

    # @return [Array] Return the tuples that are within the given percentile.
    # @param x [Float] Percentage value
    def tp_x(x)
      split_idx = (x / 100.0 * @set.size).to_i
      @set[0..split_idx]
    end

    # @return [Array] Return the tuples that are not within the given
    #         percentile.
    # @param x [Float] Percentage value
    def not_tp_x(x)
      split_idx = (x / 100.0 * @set.size).to_i
      @set[split_idx..-1]
    end

  end

end

