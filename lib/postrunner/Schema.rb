#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Schema.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # A Schema provides a unified way to query and process diverse data types.
  class Schema

    attr_reader :key, :name,
                :func, :column_alignment, :metric_unit, :imperial_unit

    # Create a Schema object.
    # @param key [Symbol] The globally unique identifier for the object
    # @param name [String] A human readable name to describe the object
    # @param opts [Hash] A Hash with values to overwrite the default values
    #        of some instance variables.
    def initialize(key, name, opts = {})
      @key = key
      @name = name

      # Default values for optional variables
      @func = nil
      @format = nil
      @column_alignment = :right
      @metric_unit = nil
      @imperial_unit = nil

      # Overwrite the default value for optional variables that have values
      # provided in opts.
      opts.each do |on, ov|
        if instance_variable_defined?('@' + on.to_s)
          instance_variable_set('@' + on.to_s, ov)
        else
          raise ArgumentError, "Unknown instance variable '#{on}'"
        end
      end
    end

    def to_s(value)
      value = send(@format, value) if @format
      value.to_s
    end

    private

    def date_with_weekday(timestamp)
      timestamp.strftime('%a, %Y %b %d %H:%M')
    end

  end

end

