#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FlexiTable_spec.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/FlexiTable'

describe PostRunner::FlexiTable do

  it 'should create a simple ASCII table' do
    t = PostRunner::FlexiTable.new do
      row(%w( a bb ))
      row(%w( ccc ddddd ))
    end
    ref = <<EOT
+---+-----+
|a  |bb   |
|ccc|ddddd|
+---+-----+
EOT
    t.to_s.should == ref
  end

end

