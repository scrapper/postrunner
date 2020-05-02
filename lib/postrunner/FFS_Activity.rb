#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = FFS_Activity.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'
require 'perobs'

require 'postrunner/ActivitySummary'
require 'postrunner/DataSources'
require 'postrunner/EventList'
require 'postrunner/ActivityView'
require 'postrunner/Schema'
require 'postrunner/QueryResult'
require 'postrunner/DirUtils'

module PostRunner

  # The FFS_Activity objects can store a reference to the FIT file data and
  # caches some frequently used values. In some cases the cached values can be
  # used to overwrite the data from the FIT file.
  class FFS_Activity < PEROBS::Object

    include DirUtils

    @@Schemata = {
      'long_date' => Schema.new('long_date', 'Date',
                                { :func => 'timestamp',
                                  :column_alignment => :left,
                                  :format => 'date_with_weekday' }),
      'sub_type' => Schema.new('sub_type', 'Subtype',
                               { :func => 'activity_sub_type',
                                 :column_alignment => :left }),
      'type' => Schema.new('type', 'Type',
                           { :func => 'activity_type',
                             :column_alignment => :left })
    }

    ActivityTypes = {
      'generic' => 'Generic',
      'running' => 'Running',
      'cycling' => 'Cycling',
      'transition' => 'Transition',
      'fitness_equipment' => 'Fitness Equipment',
      'swimming' => 'Swimming',
      'basketball' => 'Basketball',
      'soccer' => 'Soccer',
      'tennis' => 'Tennis',
      'american_football' => 'American Football',
      'walking' => 'Walking',
      'cross_country_skiing' => 'Cross Country Skiing',
      'alpine_skiing' => 'Alpine Skiing',
      'snowboarding' => 'Snowboarding',
      'rowing' => 'Rowing',
      'mountaineering' => 'Mountaneering',
      'hiking' => 'Hiking',
      'multisport' => 'Multisport',
      'paddling' => 'Paddling',
      'all' => 'All'
    }
    ActivitySubTypes = {
      'generic' => 'Generic',
      'treadmill' => 'Treadmill',
      'street' => 'Street',
      'trail' => 'Trail',
      'track' => 'Track',
      'spin' => 'Spin',
      'indoor_cycling' => 'Indoor Cycling',
      'road' => 'Road',
      'mountain' => 'Mountain',
      'downhill' => 'Downhill',
      'recumbent' => 'Recumbent',
      'cyclocross' => 'Cyclocross',
      'hand_cycling' => 'Hand Cycling',
      'track_cycling' => 'Track Cycling',
      'indoor_rowing' => 'Indoor Rowing',
      'elliptical' => 'Elliptical',
      'stair_climbing' => 'Stair Climbing',
      'lap_swimming' => 'Lap Swimming',
      'open_water' => 'Open Water',
      'flexibility_training' => 'Flexibility Training',
      'strength_training' => 'Strength Training',
      'warm_up' => 'Warm up',
      'match' => 'Match',
      'exercise' => 'Excersize',
      'challenge' => 'Challenge',
      'indoor_skiing' => 'Indoor Skiing',
      'cardio_training' => 'Cardio Training',
      'virtual_activity' => 'Virtual Activity',
      'all' => 'All'
    }

    attr_persist :device, :fit_file_name, :norecord, :name, :note, :sport,
      :sub_sport, :timestamp, :total_distance, :total_timer_time, :avg_speed
    attr_reader :fit_activity

    # Create a new FFS_Activity object.
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
      self.norecord = false
      if (@fit_activity = fit_entity)
        self.timestamp = fit_entity.timestamp
        self.total_timer_time = fit_entity.total_timer_time
        self.sport = fit_entity.sport
        self.sub_sport = fit_entity.sub_sport
        self.total_distance = fit_entity.total_distance
        self.avg_speed = fit_entity.avg_speed
      end
    end

    # Store a copy of the given FIT file in the corresponding directory.
    # @param fit_file_name [String] Fully qualified name of the FIT file.
    def store_fit_file(fit_file_name)
      # Get the right target directory for this particular FIT file.
      dir = @store['file_store'].fit_file_dir(File.basename(fit_file_name),
                                              @device.long_uid, 'activity')
      # Create the necessary directories if they don't exist yet.
      create_directory(dir, 'Device activity diretory')

      # Copy the file into the target directory.
      begin
        FileUtils.cp(fit_file_name, dir)
      rescue StandardError
        Log.fatal "Cannot copy #{fit_file_name} into #{dir}: #{$!}"
      end
    end

    # FFS_Activity objects are sorted by their timestamp values and then by
    # their device long_uids.
    def <=>(a)
      @timestamp == a.timestamp ? a.device.long_uid <=> self.device.long_uid :
        a.timestamp <=> @timestamp
    end

    def check
      generate_html_report
      Log.info "FIT file #{@fit_file_name} is OK"
    end

    def dump(filter)
      load_fit_file(filter)
    end

    def query(key)
      unless @@Schemata.include?(key)
        raise ArgumentError, "Unknown key '#{key}' requested in query"
      end

      schema = @@Schemata[key]

      if schema.func
        value = send(schema.func)
      else
        unless instance_variable_defined?(key)
          raise ArgumentError, "Don't know how to query '#{key}'"
        end
        value = instance_variable_get(key)
      end

      QueryResult.new(value, schema)
    end

    def events
      load_fit_file
      puts EventList.new(self, @store['config']['unit_system'].to_sym).to_s
    end

    def show
      html_file = html_file_name

      generate_html_report #unless File.exists?(html_file)

      @store['file_store'].show_in_browser(html_file)
    end

    def sources
      load_fit_file
      puts DataSources.new(self, @store['config']['unit_system'].to_sym).to_s
    end

    def summary
      load_fit_file
      puts ActivitySummary.new(self, @store['config']['unit_system'].to_sym,
                               { :name => @name,
                                 :type => activity_type,
                                 :sub_type => activity_sub_type }).to_s
    end

    def set(attribute, value)
      case attribute
      when 'name'
        self.name = value
      when 'note'
        self.note = value
      when 'type'
        load_fit_file
        unless ActivityTypes.values.include?(value)
          Log.fatal "Unknown activity type '#{value}'. Must be one of " +
                    ActivityTypes.values.join(', ')
        end
        self.sport = ActivityTypes.invert[value]
      when 'subtype'
        unless ActivitySubTypes.values.include?(value)
          Log.fatal "Unknown activity subtype '#{value}'. Must be one of " +
                    ActivitySubTypes.values.join(', ')
        end
        self.sub_sport = ActivitySubTypes.invert[value]
      when 'norecord'
        unless %w( true false).include?(value)
          Log.fatal "norecord must either be 'true' or 'false'"
        end
        self.norecord = value == 'true'
      else
        Log.fatal "Unknown activity attribute '#{attribute}'. Must be one of " +
                  'name, type or subtype'
      end
      generate_html_report
    end

    # Return true if this activity generated any personal records.
    def has_records?
      !@store['records'].activity_records(self).empty?
    end

    def html_file_name(full_path = true)
      fn = "#{@device.short_uid}_#{@fit_file_name[0..-5]}.html"
      full_path ? File.join(@store['config']['html_dir'], fn) : fn
    end

    def generate_html_report
      load_fit_file
      ActivityView.new(self, @store['config']['unit_system'].to_sym)
    end

    def activity_type
      ActivityTypes[@sport] || 'Undefined'
    end

    def activity_sub_type
      ActivitySubTypes[@sub_sport] || "Undefined #{@sub_sport}"
    end

    def distance(timestamp, unit_system)
      load_fit_file

      @fit_activity.records.each do |record|
        if record.timestamp >= timestamp
          unit = { :metric => 'km', :statute => 'mi'}[unit_system]
          value = record.get_as('distance', unit)
          return '-' unless value
          return "#{'%.2f %s' % [value, unit]}"
        end
      end

      '-'
    end

    def load_fit_file(filter = nil)
      return if @fit_activity

      dir = @store['file_store'].fit_file_dir(@fit_file_name,
                                              @device.long_uid, 'activity')
      fit_file = File.join(dir, @fit_file_name)
      begin
        @fit_activity = Fit4Ruby.read(fit_file, filter)
      rescue Fit4Ruby::Error
        Log.fatal "#{@fit_file_name} corrupted: #{$!}"
      end

      unless @fit_activity
        Log.fatal "#{fit_file} does not contain any activity records"
      end
    end

    def purge_fit_file
      @fit_activity = nil
    end

  end

end

