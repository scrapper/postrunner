#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = QueryResult.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # Queries provide an abstract interface to retrieve individual values from
  # Activities, Laps and so on. The result of a query is returned as a
  # QueryResult object.
  class QueryResult

    # Create a QueryResult object.
    # @param value [any] Result of the query
    # @param schema [Schema] A reference to the Schema of the queried
    #        attribute.
    def initialize(value, schema)
      @value = value
      @schema = schema
    end

    # Conver the result into a text String.
    def to_s
      @schema.to_s(@value)
    end

  end

end
