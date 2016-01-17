#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FFS_Device.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'perobs'
require 'postrunner/FFS_Activity'

module PostRunner

  # Objects of this class can store the activities and monitoring data of a
  # specific device. The device gets a random number assigned as a unique but
  # anonymous ID. It also gets a long ID assigned that is a String of the
  # manufacturer, the product name and the serial number concatenated by
  # dashes. All objects are transparently stored in the PEROBS::Store.
  class FFS_Device < PEROBS::Object

    po_attr :activities, :monitorings, :short_uid, :long_uid

    # Create a new FFS_Device object.
    # @param cf [PEROBS::ConstructorForm] cf
    # @param short_uid [Fixnum] A random number used a unique ID
    # @param long_uid [String] A string consisting of the manufacturer and
    #        product name and the serial number.
    def initialize(cf, short_uid, long_uid)
      super(cf)
      self.short_uid = short_uid
      self.long_uid = long_uid
      restore
    end

    # Handle initialization of persistent attributes.
    def restore
      attr_init(:activities) { @store.new(PEROBS::Array) }
      attr_init(:monitorings) { @store.new(PEROBS::Array) }
    end

    # Add a new FIT file for this device.
    # @param fit_file_name [String] The full path to the FIT file
    # @param fit_entity [Fit4Ruby::FitEntity] The content of the FIT file
    # @param overwrite [Boolean] A flag to indicate if an existing file should
    #        be replaced with the new one.
    # @return [FFS_Activity or FFS_Monitoring] Corresponding entry in the
    #         FitFileStore or nil if file could not be added.
    def add_fit_file(fit_file_name, fit_entity, overwrite)
      case fit_entity.class
      when Fit4Ruby::Activity.class
        entity = activity_by_file_name(File.basename(fit_file_name))
        entities = @activities
        type = 'activity'
        new_entity_class = FFS_Activity
      when Fit4Ruby::Monitoring.class
        entity = monitoring_by_file_name(File.basename(fit_file_name))
        entities = @monitorings
        type = 'monitoring'
        new_entity_class = FFS_Monitoring
      else
        Log.fatal "Unsupported FIT entity #{fit_entity.class}"
      end

      if entity
        if overwrite
          # Replace the old file. All meta-information will be lost.
          entities.delete_if { |e| e.fit_file_name == fit_file_name }
          entity = @store.new(new_entity_class, myself, fit_file_name,
                              fit_entity)
        else
          # Refuse to replace the file.
          return nil
        end
      else
        # Don't add the entity if has deleted before and overwrite isn't true.
        path = @store['file_store'].fit_file_dir(File.basename(fit_file_name),
                                                 long_uid, type)
        fq_fit_file_name = File.join(path, File.basename(fit_file_name))
        if File.exists?(fq_fit_file_name) && !overwrite
          return nil
        end
        # Add the new file to the list.
        entity = @store.new(new_entity_class, myself, fit_file_name, fit_entity)
      end
      entity.store_fit_file(fit_file_name)
      entities << entity
      entities.sort!

      # Scan the activity for any potential new personal records and register
      # them.
      if entity.is_a?(FFS_Activity)
        records = @store['records']
        records.scan_activity_for_records(entity, true)
      end

      entity
    end

    # Delete the given activity from the activity list.
    # @param activity [FFS_Activity] activity to delete
    def delete_activity(activity)
      @activities.delete(activity)
    end

    # Return the activity with the given file name.
    # @param file_name [String] Base name of the fit file.
    # @return [FFS_Activity] Corresponding FFS_Activity or nil.
    def activity_by_file_name(file_name)
      @activities.find { |a| a.fit_file_name == file_name }
    end

    # Return the monitoring with the given file name.
    # @param file_name [String] Base name of the fit file.
    # @return [FFS_Activity] Corresponding FFS_Monitoring or nil.
    def monitoring_by_file_name(file_name)
      @monitorings.find { |a| a.fit_file_name == file_name }
    end

  end

end

