#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FitFileStore.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'
require 'perobs'

require 'postrunner/Log'
require 'postrunner/DirUtils'
require 'postrunner/FFS_Device'
require 'postrunner/ActivityListView'
require 'postrunner/ViewButtons'
require 'postrunner/MonitoringStatistics'

module PostRunner

  # The FitFileStore stores all FIT file and provides access to the contained
  # data.
  class FitFileStore < PEROBS::Object

    include DirUtils

    po_attr :devices

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
      # Ensure that we have an Array in the store to hold all known devices.
      @store['devices'] = @store.new(PEROBS::Hash) unless @store['devices']

      @devices_dir = File.join(@data_dir, 'devices')
      # It's generally not a good idea to store absolute file names in the
      # database. We'll make an exception here as this is the only way to
      # propagate this path to FFS_Activity or FFS_Monitoring objects. The
      # store entry is updated on each program run, so the DB can be moved
      # safely to another directory.
      @store['config']['devices_dir'] = @devices_dir
      create_directory(@devices_dir, 'devices')

      # Define which View objects the HTML output will consist of. This
      # doesn't really belong in this class but for now it's the best place
      # to put it.
      @views = ViewButtons.new([
        NavButtonDef.new('activities.png', 'index.html'),
        NavButtonDef.new('record.png', "records-0.html")
      ])
    end

    # Version upgrade logic.
    def handle_version_update
      # Nothing here so far.
    end

    # Add a file to the store.
    # @param fit_file_name [String] Name of the FIT file
    # @param overwrite [TrueClass, FalseClass] If true, an existing file will
    #        be replaced.
    # @return [FFS_Activity or FFS_Monitoring] Corresponding entry in the
    #         FitFileStore or nil if file could not be added.
    def add_fit_file(fit_file_name, fit_entity = nil, overwrite = false)
      # If we the file hasn't been read yet, read it in as a
      # Fit4Ruby::Activity or Fit4Ruby::Monitoring entity.
      unless fit_entity
        return nil unless (fit_entity = read_fit_file(fit_file_name))
      end

      unless [ Fit4Ruby::Activity,
               Fit4Ruby::Monitoring_B ].include?(fit_entity.class)
        Log.fatal "Unsupported FIT file type #{fit_entity.class}"
      end

      # Generate a String that uniquely identifies the device that generated
      # the FIT file.
      id = extract_fit_file_id(fit_entity)
      long_uid = "#{id[:manufacturer]}-#{id[:product]}-#{id[:serial_number]}"

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
      activities.each do |activity|
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
      list.sort
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
      activities.sort do |a1, a2|
        a1.timestamp <=> a2.timestamp
      end.each do |a|
        a.check
        records.scan_activity_for_records(a)
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
        Log.fatal 'FIT file has no file_id section'
      end

      if fid.manufacturer == 'garmin' &&
         fid.garmin_product == 'fr920xt'
        # Garmin Fenix3 with firmware before 6.80 is reporting 'fr920xt' in
        # the file_id section but 'fenix3' in the first device_info section.
        # To tell the Fenix3 apart from the FR920XT we need to look into the
        # device_info section for all devices with a garmin_product of
        # 'fr920xt'.
        fit_entity.device_infos.each do |di|
          if di.device_index == 0
            return {
              :manufacturer => di.manufacturer,
              :product => di.garmin_product || di.product,
              :serial_number => di.serial_number
            }
          end
        end
        Log.fatal "Fit entity has no device info for 0"
      else
        # And for all properly developed devices we can just look at the
        # file_id section.
        return {
          :manufacturer => fid.manufacturer,
          :product => fid.garmin_product || fid.product,
          :serial_number => fid.serial_number
        }
      end
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
        create_directory(File.join(@devices_dir, long_uid), long_uid)
      end

      @store['devices'][long_uid]
    end

    def generate_html_index_pages
      # Ensure that HTML index is up-to-date.
      ActivityListView.new(myself).update_index_pages
    end

  end

end

