#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DirUtils.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'

module PostRunner

  module DirUtils

    def create_directory(dir, name)
      return if Dir.exist?(dir)

      Log.info "Creating #{name} directory #{dir}"
      begin
        FileUtils.mkdir_p(dir)
      rescue StandardError
        Log.fatal "Cannot create #{name} directory #{dir}: #{$!}"
      end
    end

  end

end
