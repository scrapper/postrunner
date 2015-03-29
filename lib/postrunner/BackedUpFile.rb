#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivitiesDB.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # BackUpFile is a specialized version of File that creates a copy on
  class BackedUpFile < File

     def BackedUpFile.open(filename, mode = 'r', *opt, &block)
       # If the file is opened for writing we create a backup file.
       create_backup_file(filename) if mode.include?('w') || mode.include?('a')
       super
     end

     def BackedUpFile.write(filename, string)
       create_backup_file(filename)
       super
     end

     private

     def BackedUpFile.create_backup_file(filename)
       bak_file = filename + '.bak'

       # Delete the backup file if it exists.
       if File.exists?(bak_file)
         begin
           File.delete(bak_file)
         rescue SystemCallError
           Log.fatal "Cannote remove backup file '#{bak_file}': #{$!}"
         end
       end

       # Rename the old file to <filename>.bak
       if File.exists?(filename)
         begin
           File.rename(filename, bak_file)
         rescue SystemCallError
           Log.fatal "Cannot rename file '#{filename}' to '#{bak_file}': #{$!}"
         end
       end
     end

  end

end

