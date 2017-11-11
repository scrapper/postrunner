#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FFS_Monitoring.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'
require 'perobs'

module PostRunner

  # The FFS_Monitoring objects can store a reference to the FIT file data and
  # caches some frequently used values.
  class FFS_Monitoring < PEROBS::Object

    include DirUtils

    attr_persist :device, :fit_file_name, :name, :period_start, :period_end

    # Create a new FFS_Monitoring object.
    # @param p [PEROBS::Handle] PEROBS handle
    # @param fit_file_name [String] The fully qualified file name of the FIT
    #        file to add
    # @param fit_entity [Fit4Ruby::FitEntity] The content of the loaded FIT
    #        file
    def initialize(p, device, fit_file_name, fit_entity)
      super(p)

      self.device = device
      self.fit_file_name = fit_file_name ? File.basename(fit_file_name) : nil
      self.name = fit_file_name ? File.basename(fit_file_name) : nil

      extract_summary_values(fit_entity)
    end

    # Store a copy of the given FIT file in the corresponding directory.
    # @param fit_file_name [String] Fully qualified name of the FIT file.
    def store_fit_file(fit_file_name)
      # Get the right target directory for this particular FIT file.
      dir = @store['file_store'].fit_file_dir(File.basename(fit_file_name),
                                              @device.long_uid, 'monitor')
      # Create the necessary directories if they don't exist yet.
      create_directory(dir, 'Device monitoring diretory')

      # Copy the file into the target directory.
      begin
        FileUtils.cp(fit_file_name, dir)
      rescue StandardError
        Log.fatal "Cannot copy #{fit_file_name} into #{dir}: #{$!}"
      end
    end

    # FFS_Monitoring objects are sorted by their start time values and then by
    # their device long_uids.
    def <=>(a)
      @period_start == a.period_start ?
        a.device.long_uid <=> self.device.long_uid :
        a.period_start <=> @period_start
    end

    private

    def extract_summary_values(fit_entity)
      self.period_start = fit_entity.monitoring_infos[0].timestamp

      period_end = @period_start
      fit_entity.monitorings.each do |monitoring|
        period_end = monitoring.timestamp if monitoring.timestamp
      end
      self.period_end = period_end
    end

    def decode_activity_type(activity_type)
      types = [ :generic, :running, :cycling, :transition,
                :fitness_equipment, :swimming, :walking, :unknown7,
                :resting, :unknown9 ]
      if (decoded_type = types[activity_type])
        decoded_type
      else
        Log.error "Unknown activity type #{activity_type}"
        :generic
      end
    end

  end

end

