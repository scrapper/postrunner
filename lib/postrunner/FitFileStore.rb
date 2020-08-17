#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FitFileStore.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015, 2016, 2018 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'digest'
require 'fit4ruby'
require 'perobs'

require 'postrunner/Log'
require 'postrunner/DirUtils'
require 'postrunner/FFS_Device'
require 'postrunner/ActivityListView'
require 'postrunner/DailyMonitoringView'
require 'postrunner/ViewButtons'
require 'postrunner/MonitoringStatistics'

module PostRunner

  # The FitFileStore stores all FIT file and provides access to the contained
  # data.
  class FitFileStore < PEROBS::Object

    include DirUtils

    attr_persist :devices

    attr_reader :store, :views

    # Create a new FIT file store.
    # @param p [PEROBS::Handle] PEROBS handle
    def initialize(p)
      super(p)
      restore
    end

    # Setup non-persistent variables.
    def restore
      @data_dir = @store['config']['data_dir']
      # Ensure that we have a Hash in the store to hold all known devices.
      @store['devices'] = @store.new(PEROBS::Hash) unless @store['devices']

      @devices_dir = File.join(@data_dir, 'devices')
      # It's generally not a good idea to store absolute file names in the
      # database. We'll make an exception here as this is the only way to
      # propagate this path to FFS_Activity or FFS_Monitoring objects. The
      # store entry is updated on each program run, so the DB can be moved
      # safely to another directory.
      @store['config']['devices_dir'] = @devices_dir
      create_directory(@devices_dir, 'devices')
      unless @store['fit_file_md5sums']
        @store['fit_file_md5sums'] = @store.new(PEROBS::Array)
      end

      # Define which View objects the HTML output will consist of. This
      # doesn't really belong in this class but for now it's the best place
      # to put it.
      @views = ViewButtons.new([
        NavButtonDef.new('activities.png', 'index.html'),
        NavButtonDef.new('record.png', "records-0.html")
      ])
    end

    # Version upgrade logic.
    def handle_version_update(from_version, to_version)
      if from_version <= Gem::Version.new('0.12.0')
        # PostRunner up until version 0.12.0 was using a long_uid with
        # manufacturer name and product name. This was a bad idea since unknown
        # devices were resolved to their numerical ID. In case the unknown ID
        # was later added to the dictionary in fit4ruby version update, it
        # resolved to its name and the device was recognized as a new device.
        # Versions after 0.12.0 only use the numerical versions for the device
        # long_uid and directory names.
        uid_remap = {}
        @store['devices'].each do |uid, device|
          old_uid = uid

          if (first_activity = device.activities.first)
            first_activity.load_fit_file
            if  (fit_activity = first_activity.fit_activity)
              if (device_info = fit_activity.device_infos.first)
                new_uid = "#{device_info.numeric_manufacturer}-" +
                  "#{device_info.numeric_product}-#{device_info.serial_number}"

                uid_remap[old_uid] = new_uid
                puts first_activity.fit_file_name
              end
            end
          end
        end

        @store.transaction do
          pwd = Dir.pwd
          base_dir_name = @store['config']['devices_dir']
          Dir.chdir(base_dir_name)

          uid_remap.each do |old_uid, new_uid|
            if Dir.exist?(old_uid) && !Dir.exist?(new_uid) &&
                !File.symlink?(old_uid)
              # Rename the directory from the old (string) scheme to the
              # new numeric scheme.
              FileUtils.mv(old_uid, new_uid)
              # Create a symbolic link with that points the old name to
              # the new name.
              File.symlink(new_uid, old_uid)
            end

            # Now update the long_uid in the FFS_Device object
            @store['devices'][new_uid] = device = @store['devices'][old_uid]
            device.long_uid = new_uid
            @store['devices'].delete(old_uid)
          end

          Dir.chdir(pwd)
        end
      end
    end

    # Add a file to the store.
    # @param fit_file_name [String] Name of the FIT file
    # @param overwrite [TrueClass, FalseClass] If true, an existing file will
    #        be replaced.
    # @return [FFS_Activity or FFS_Monitoring] Corresponding entry in the
    #         FitFileStore or nil if file could not be added.
    def add_fit_file(fit_file_name, fit_entity = nil, overwrite = false)
      # If the file hasn't been read yet, read it in as a
      # Fit4Ruby::Activity or Fit4Ruby::Monitoring entity.
      unless fit_entity
        return nil unless (fit_entity = read_fit_file(fit_file_name))
      end

      unless [ Fit4Ruby::Activity,
               Fit4Ruby::Monitoring_B,
               Fit4Ruby::Metrics ].include?(fit_entity.class)
        Log.fatal "Unsupported FIT file type #{fit_entity.class}"
      end

      # Generate a String that uniquely identifies the device that generated
      # the FIT file.
      id = extract_fit_file_id(fit_entity)
      long_uid = "#{id[:numeric_manufacturer]}-" +
        "#{id[:numeric_product]}-#{id[:serial_number]}"

      # Make sure the device that created the FIT file is properly registered.
      device = register_device(long_uid)
      # Store the FIT entity with the device.
      entity = device.add_fit_file(fit_file_name, fit_entity, overwrite)

      # The FIT file might be already stored or invalid. In that case we
      # abort this method.
      return nil unless entity

      if fit_entity.is_a?(Fit4Ruby::Activity)
        @store['records'].scan_activity_for_records(entity)

        # Generate HTML file for this activity.
        entity.generate_html_report

        # The HTML activity views contain links to their predecessors and
        # successors. After inserting a new activity, we need to re-generate
        # these views as well.
        if (pred = predecessor(entity))
          pred.generate_html_report
        end
        if (succ = successor(entity))
          succ.generate_html_report
        end
        # And update the index pages
        generate_html_index_pages
      end

      Log.info "#{File.basename(fit_file_name)} " +
               'has been successfully added to archive'

      entity
    end

    # Delete an activity from the database. It will only delete the entry in
    # the database. The original activity file will not be deleted from the
    # file system.
    # @param activity [FFS_Activity] Activity to delete
    def delete_activity(activity)
      pred = predecessor(activity)
      succ = successor(activity)

      activity.device.delete_activity(activity)

      # The HTML activity views contain links to their predecessors and
      # successors. After deleting an activity, we need to re-generate these
      # views.
      pred.generate_html_report if pred
      succ.generate_html_report if succ

      generate_html_index_pages
    end

    # Rename the specified activity and update all HTML pages that contain the
    # name.
    # @param activity [FFS_Activity] Activity to rename
    # @param name [String] New name
    def rename_activity(activity, name)
      activity.set('name', name)
      generate_html_index_pages
      @store['records'].generate_html_reports if activity.has_records?
    end

    # Set the specified attribute of the given activity to a new value.
    # @param activity [FFS_Activity] Activity to rename
    # @param attribute [String] name of the attribute to change
    # @param value [any] new value of the attribute
    def set_activity_attribute(activity, attribute, value)
      activity.set(attribute, value)
      case attribute
      when 'norecord', 'type'
        # If we have changed a norecord setting or an activity type, we need
        # to regenerate all reports and re-collect the record list since we
        # don't know which Activity needs to replace the changed one.
        check
      end
      generate_html_index_pages
    end

    # Perform the necessary report updates after the unit system has been
    # changed.
    def change_unit_system
      # If we have changed the unit system we need to re-generate all HTML
      # reports.
      activities.reverse.each do |activity|
        activity.generate_html_report
      end
      @store['records'].generate_html_reports
      generate_html_index_pages
    end

    # Determine the right directory for the given FIT file. The resulting path
    # looks something like /home/user/.postrunner/devices/garmin-fenix3-1234/
    # activity/5A.
    # @param fit_file_base_name [String] The base name of the fit file
    # @param long_uid [String] the long UID of the device
    # @param type [String] 'activity' or 'monitoring'
    # @return [String] the full path name of the archived FIT file
    def fit_file_dir(fit_file_base_name, long_uid, type)
      # The first letter of the FIT file specifies the creation year.
      # The second letter of the FIT file specifies the creation month.
      File.join(@store['config']['devices_dir'],
                long_uid, type, fit_file_base_name[0..1])
    end



    # @return [Array of FFS_Device] List of registered devices.
    def devices
      @store['devices']
    end

    # @return [Array of FFS_Activity] List of stored activities.
    def activities
      list = []
      @store['devices'].each do |id, device|
        list += device.activities
      end
      # Sort the activites by timestamps (newest to oldest). As the list is
      # composed from multiple devices, there is a small chance of identical
      # timestamps. To guarantee a stable list, we use the long UID of the
      # device in cases of identical timestamps.
      list.sort! do |a1, a2|
        a1.timestamp == a2.timestamp ?
          a1.device.long_uid <=> a2.device.long_uid :
          a2.timestamp <=> a1.timestamp
      end

      list
    end

    # Read in all Monitoring_B FIT files that overlap with the given interval.
    # @param start_date [Time] Interval start time
    # @param end_date [Time] Interval end date
    # @return [Array of Monitoring_B] Content of Monitoring_B FIT files
    def monitorings(start_date, end_date)
      monitorings = []
      @store['devices'].each do |id, device|
        monitorings += device.monitorings(start_date.gmtime, end_date.gmtime)
      end

      monitorings.reverse.map do |m|
        read_fit_file(File.join(fit_file_dir(m.fit_file_name, m.device.long_uid,
                                             'monitor'), m.fit_file_name))
      end
    end


    # Return the reference index of the given FFS_Activity.
    # @param activity [FFS_Activity]
    # @return [Fixnum] Reference index as used in the UI
    def ref_by_activity(activity)
      return nil unless (idx = activities.index(activity))

      idx + 1
    end

    # Return the next Activity after the provided activity. Note that this has
    # a lower index. If none is found, return nil.
    def successor(activity)
      all_activities = activities
      idx = all_activities.index(activity)
      return nil if idx.nil? || idx == 0
      all_activities[idx - 1]
    end

    # Return the previous Activity before the provided activity.
    # If none is found, return nil.
    def predecessor(activity)
      all_activities = activities
      idx = all_activities.index(activity)
      return nil if idx.nil?
      # Activities indexes are reversed. The predecessor has a higher index.
      all_activities[idx + 1]
    end

    # Find a specific subset of the activities based on their index.
    # @param query [String]
    def find(query)
      case query
      when /\A-?\d+$\z/
        index = query.to_i
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        if index <= 0
          Log.error 'Index must be larger than 0'
          return []
        end
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        if (a = activities[index - 1])
          return [ a ]
        end
      when /\A-?\d+--?\d+\z/
        idxs = query.match(/(?<sidx>-?\d+)-(?<eidx>-?[0-9]+)/)
        if (sidx = idxs['sidx'].to_i) <= 0
          Log.error 'Start index must be larger than 0'
          return []
        end
        if (eidx = idxs['eidx'].to_i) <= 0
          Log.error 'End index must be larger than 0'
          return []
        end
        if eidx < sidx
          Log.error 'Start index must be smaller than end index'
          return []
        end
        # The UI counts the activities from 1 to N. Ruby counts from 0 -
        # (N-1).
        unless (as = activities[(sidx - 1)..(eidx - 1)]).empty?
          return as
        end
      else
        Log.error "Invalid activity query: #{query}"
      end

      []
    end

    # This methods checks all stored FIT files for correctness, updates all
    # indexes and re-generates all HTML reports.
    def check
      records = @store['records']
      records.delete_all_records
      activities.reverse.each do |a|
        a.check
        records.scan_activity_for_records(a)
        a.purge_fit_file
      end
      records.generate_html_reports
      generate_html_index_pages
    end

    # Show the activity list in a web browser.
    def show_list_in_browser
      generate_html_index_pages
      @store['records'].generate_html_reports
      show_in_browser(File.join(@store['config']['html_dir'], 'index.html'))
    end

    def list_activities
      puts ActivityListView.new(self).to_s
    end

    # Launch a web browser and show an HTML file.
    # @param html_file [String] file name of the HTML file to show
    def show_in_browser(html_file)
      cmd = "#{ENV['BROWSER'] || 'firefox'} \"#{html_file}\" &"

      unless system(cmd)
        Log.fatal "Failed to execute the following shell command: #{$cmd}\n" +
                  "#{$!}"
      end
    end

    def show_monitoring(day)
      # 'day' specifies the current day. But we don't know what timezone the
      # watch was set to for a given date. The files are always named after
      # the moment of finishing the recording expressed as GMT time.
      # Each file contains information about the time zone for the specific
      # file. Recording is always flipped to a new file at midnight GMT but
      # there are usually multiple files per GMT day.
      day_as_time = Time.parse(day).gmtime
      # To get weekly intensity minutes we need 7 days of data prior to the
      # current date and 1 day after to include the following night. We add
      # at least 12 extra hours to accomodate time zone changes.
      monitoring_files = monitorings(day_as_time - 8 * 24 * 60 * 60,
                                     day_as_time + 36 * 60 * 60)

      show_in_browser(DailyMonitoringView.new(@store, day, monitoring_files).
                      file_name)
    end

    def daily_report(day)
      # 'day' specifies the current day. But we don't know what timezone the
      # watch was set to for a given date. The files are always named after
      # the moment of finishing the recording expressed as GMT time.
      # Each file contains information about the time zone for the specific
      # file. Recording is always flipped to a new file at midnight GMT but
      # there are usually multiple files per GMT day.
      day_as_time = Time.parse(day).gmtime
      # To get weekly intensity minutes we need 7 days of data prior to the
      # current date and 1 day after to include the following night. We add
      # at least 12 extra hours to accomodate time zone changes.
      monitoring_files = monitorings(day_as_time - 8 * 24 * 60 * 60,
                                     day_as_time + 36 * 60 * 60)

      puts MonitoringStatistics.new(monitoring_files).daily(day)
    end

    def weekly_report(day)
      # 'day' specifies the current week. It must be in the form of
      # YYYY-MM-DD and references a day in the specific week. But we don't
      # know what timezone the watch was set to for a given date. The files
      # are always named after the moment of finishing the recording expressed
      # as GMT time.  Each file contains information about the time zone for
      # the specific file. Recording is always flipped to a new file at
      # midnight GMT but there are usually multiple files per
      # GMT day.
      day_as_time = Time.parse(day).gmtime
      start_day = day_as_time -
        (24 * 60 * 60 * (day_as_time.wday - @store['config']['week_start_day']))
      # To get weekly intensity minutes we need 7 days of data prior to the
      # current month start and 1 after to include the following night. We add
      # at least 12 extra hours to accomondate time zone changes.
      monitoring_files = monitorings(start_day - 8 * 24 * 60 * 60,
                                     start_day + 8 * 24 * 60 * 60)

      puts MonitoringStatistics.new(monitoring_files).weekly(start_day)
    end

    def monthly_report(day)
      # 'day' specifies the current month. It must be in the form of
      # YYYY-MM-01. But we don't know what timezone the watch was set to for a
      # given date. The files are always named after the moment of finishing
      # the recording expressed as GMT time.  Each file contains information
      # about the time zone for the specific file. Recording is always flipped
      # to a new file at midnight GMT but there are usually multiple files per
      # GMT day.
      day_as_time = Time.parse(day).gmtime
      # To get weekly intensity minutes we need 7 days of data prior to the
      # current month start and 1 after to inclide the following night. We add
      # at least 12 extra hours to accomondate time zone changes.
      monitoring_files = monitorings(day_as_time - 8 * 24 * 60 * 60,
                                     day_as_time + 32 * 24 * 60 * 60)

      puts MonitoringStatistics.new(monitoring_files).monthly(day)
    end

    def FitFileStore::calc_md5_sum(file_name)
      begin
        Digest::MD5.hexdigest File.read(file_name)
      rescue IOError
        return 0
      end
    end

    private

    def read_fit_file(fit_file_name)
      begin
        return Fit4Ruby.read(fit_file_name)
      rescue Fit4Ruby::Error
        Log.error $!
        return nil
      end
    end

    def extract_fit_file_id(fit_entity)
      unless (fid = fit_entity.file_id)
        Log.error 'FIT file has no file_id section'
        return nil
      end

      fit_entity.device_infos.each do |di|
        if di.device_index == 0
          return {
            :manufacturer => di.manufacturer,
            :product => di.garmin_product || di.product,
            :numeric_manufacturer => di.numeric_manufacturer,
            :numeric_product => di.numeric_product,
            :serial_number => di.serial_number || 0
          }
        end
      end

      Log.error "Fit entity has no device info for 0"
      return nil
    end

    def register_device(long_uid)
      unless @store['devices'].include?(long_uid)
        Log.info "New device registered: #{long_uid}"

        # Generate a unique ID for the device that does not allow any insight
        # on the number of and type of managed devices.
        begin
          short_uid = rand(2**32)
        end while @store['devices'].find { |luid, d| d.short_uid == short_uid }

        @store['devices'][long_uid] =
          @store.new(FFS_Device, short_uid, long_uid)

        # Create the directory to store the FIT files of this device.
        create_directory(File.join(@devices_dir, long_uid),
                         long_uid)
      end

      @store['devices'][long_uid]
    end

    def generate_html_index_pages
      # Ensure that HTML index is up-to-date.
      ActivityListView.new(myself).update_index_pages
    end

  end

end

