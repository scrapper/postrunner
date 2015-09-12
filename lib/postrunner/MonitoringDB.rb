#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MonitoringDB.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  class MonitoringDB

    def initialize(db, cfg)
      db.sync
    end

  end

end
