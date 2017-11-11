#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LinearPredictor.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # For now we use a trivial adaptive linear predictor that just uses the
  # average of past values to predict the next value.
  class LinearPredictor

    # Create a new LinearPredictor object.
    # @param n [Fixnum] The number of coefficients the predictor should use.
    def initialize(n)
      @values = []
      @size = n
      @next = nil
    end

    # Tell the predictor about the actual next value.
    # @param value [Float] next value
    def insert(value)
      @values << value

      if @values.length >= @size
        @values.shift
      end

      @next = @values.reduce(:+) / @values.size
      $stderr.puts "insert(#{value})  next: #{@next}"
    end

    # @return [Float] The predicted value of the next sample.
    def predict
      @next
    end

  end

end

