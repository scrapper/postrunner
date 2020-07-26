#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Log.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

module PostRunner

  # Use the Logger provided by Fit4Ruby for all console output.
  Log = Fit4Ruby::ILogger.instance
  Log.formatter = proc { |severity, datetime, progname, msg|
    "#{severity == Logger::INFO ? '' : "#{severity}:"} #{msg}\n"
  }
  Log.level = Logger::WARN

end

