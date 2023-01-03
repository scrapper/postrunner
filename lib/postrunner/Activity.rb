#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Activity.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/ActivitySummary'
require 'postrunner/DataSources'
require 'postrunner/EventList'
require 'postrunner/ActivityView'
require 'postrunner/Schema'
require 'postrunner/QueryResult'

module PostRunner

  class Activity

    attr_reader :db, :fit_file, :name, :fit_activity

    # This is a list of variables that provide data from the fit file. To
    # speed up access to it, we cache the data in the activity database.
    @@CachedActivityValues = %w( sport sub_sport timestamp total_distance
                                 total_timer_time avg_speed )
    # We also store some additional information in the archive index.
    @@CachedAttributes = @@CachedActivityValues + %w( fit_file name norecord )

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
      'training' => 'Training',
      'flying' => 'Flying',
      'e_biking' => 'E-Biking',
      'motorcycling' => 'Motor Cycling',
      'boating' => 'Boating',
      'driving' => 'Driving',
      'golf' => 'Golf',
      'hang_gliding' => 'Hang Gliding',
      'horseback_riding' => 'Horseback Riding',
      'hunting' => 'Hunting',
      'fishing' => 'Fishing',
      'inline_skating' => 'Inline Skating',
      'rock_climbing' => 'Rock Climbing',
      'sailing' => 'Sailing',
      'ice_skating' => 'Ice Skating',
      'sky_diving' => 'Sky Diving',
      'snowshoeing' => 'Snowshoeing',
      'snowmobiling' => 'Snowmobiling',
      'stand_up_paddleboarding' => 'Stand Up Paddleboarding',
      'surfing' => 'Surfing',
      'wakeboarding' => 'Wakeboarding',
      'water_skiing' => 'Water Skiing',
      'kayaking' => 'Kayaking',
      'rafting' => 'Rafting',
      'windsurfing' => 'Windsurfing',
      'kitesurfing' => 'Kitesurfing',
      'tactical' => 'Tactical',
      'jumpmaster' => 'Jumpmaster',
      'boxing' => 'Boxing',
      'floor_climbing' => 'Floor Climbing',
      'diving' => 'Diving',
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
      'e_bike_fitness' => 'E Bike Fittness',
      'bmx' => 'BMX',
      'casual_walking' => 'Casual Walking',
      'speed_walking' => 'Speed Walking',
      'bike_to_run_transition' => 'Bike to Run Transition',
      'run_to_bike_transition' => 'Run to Bike Transition',
      'swim_to_bike_transition' => 'Swim to Bike Transition',
      'atv' => 'ATV',
      'motocross' => 'Motocross',
      'backcountry' => 'Backcountry',
      'resort' => 'Resort',
      'rc_drone' => 'RC Drone',
      'wingsuit' => 'Wingsuite',
      'whitewater' => 'Whitemaster',
      'skate_skiing' => 'Skate Skiing',
      'yoga' => 'Yoga',
      'pilates' => 'Pilates',
      'indoor_running' => 'Indoor Running',
      'gravel_cycling' => 'Gravel Cycling',
      'e_bike_mountain' => 'E-Bike Mountain',
      'commuting' => 'Commuting',
      'mixed_surface' => 'Mixed Surface',
      'navigate' => 'Navigate',
      'track_me' => 'Track Me',
      'map' => 'Map',
      'single_gas_diving' => 'Single Gas Diving',
      'multi_gas_diving' => 'Multi Gas Diving',
      'gauge_diving' => 'Gauge Diving',
      'apnea_diving' => 'Apnea Diving',
      'apnea_hunting' => 'Apnea Hunting',
      'virtual_activity' => 'Virtual Activity',
      'obstacle' => 'Obstacle',
      'breathing' => 'Breating',
      'sail_race' => 'Sail Race',
      'ultra' => 'Ultra',
      'indoor_climbing' => 'Indoor Climbing',
      'bouldering' => 'Bouldering',
      'all' => 'All'
    }

    def initialize(db, fit_file, fit_activity, name = nil)
      @fit_file = fit_file
      @fit_activity = fit_activity
      @name = name || fit_file
      @unset_variables = []
      late_init(db)

      @@CachedActivityValues.each do |v|
        v_str = "@#{v}"
        instance_variable_set(v_str, fit_activity.send(v))
        self.class.send(:attr_reader, v.to_sym)
      end
    end

    # YAML::load() does not call initialize(). We don't have all attributes
    # stored in the YAML file, so we need to make sure these are properly set
    # after a YAML::load().
    def late_init(db)
      @db = db
      @html_file = File.join(@db.cfg[:html_dir], "#{@fit_file[0..-5]}.html")

      @unset_variables.each do |name_without_at|
        # The YAML file does not yet have the instance variable cached.
        # Load the Activity data and extract the value to set the instance
        # variable.
        @fit_activity = load_fit_file unless @fit_activity
        instance_variable_set('@' + name_without_at,
                              @fit_activity.send(name_without_at))
      end
    end

    def check
      generate_html_view
      register_records
      Log.info "FIT file #{@fit_file} is OK"
    end

    def dump(filter)
      @fit_activity = load_fit_file(filter)
    end

    # This method is called during YAML::load() to initialize the class
    # objects. The initialize() is NOT called during YAML::load(). Any
    # additional initialization work is done in late_init().
    def init_with(coder)
      @unset_variables = []
      @@CachedAttributes.each do |name_without_at|
        # Create attr_readers for cached variables.
        self.class.send(:attr_reader, name_without_at.to_sym)

        if coder.map.include?(name_without_at)
          # The YAML file has a value for the instance variable. So just set
          # it.
          instance_variable_set('@' + name_without_at, coder[name_without_at])
        else
          if @@CachedActivityValues.include?(name_without_at)
            @unset_variables << name_without_at
          elsif name_without_at == 'norecord'
            @norecord = false
          else
            Log.fatal "Don't know how to initialize the instance variable " +
                      "#{name_without_at}."
          end
        end
      end
    end

    # This method is called during Activity::to_yaml() calls. It's being used
    # to prevent some instance variables from being saved in the YAML file.
    # Only attributes that are listed in @@CachedAttributes are being saved.
    def encode_with(coder)
      instance_variables.each do |a|
        name_with_at = a.to_s
        name_without_at = name_with_at[1..-1]
        next unless @@CachedAttributes.include?(name_without_at)

        coder[name_without_at] = instance_variable_get(name_with_at)
      end
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
      @fit_activity = load_fit_file unless @fit_activity
      puts EventList.new(self, @db.cfg[:unit_system]).to_s
    end

    def show
      generate_html_view #unless File.exist?(@html_file)

      @db.show_in_browser(@html_file)
    end

    def sources
      @fit_activity = load_fit_file unless @fit_activity
      puts DataSources.new(self, @db.cfg[:unit_system]).to_s
    end

    def summary
      @fit_activity = load_fit_file unless @fit_activity
      puts ActivitySummary.new(self, @db.cfg[:unit_system],
                               { :name => @name,
                                 :type => activity_type,
                                 :sub_type => activity_sub_type }).to_s
    end

    def rename(name)
      @name = name
      generate_html_view
    end

    def set(attribute, value)
      case attribute
      when 'name'
        @name = value
      when 'type'
        @fit_activity = load_fit_file unless @fit_activity
        unless ActivityTypes.values.include?(value)
          Log.fatal "Unknown activity type '#{value}'. Must be one of " +
                    ActivityTypes.values.join(', ')
        end
        @sport = ActivityTypes.invert[value]
        # Since the activity changes the records from this Activity need to be
        # removed and added again.
        @db.records.delete_activity(self)
        register_records
      when 'subtype'
        unless ActivitySubTypes.values.include?(value)
          Log.fatal "Unknown activity subtype '#{value}'. Must be one of " +
                    ActivitySubTypes.values.join(', ')
        end
        @sub_sport = ActivitySubTypes.invert[value]
      when 'norecord'
        unless %w( true false).include?(value)
          Log.fatal "norecord must either be 'true' or 'false'"
        end
        @norecord = value == 'true'
      else
        Log.fatal "Unknown activity attribute '#{attribute}'. Must be one of " +
                  'name, type or subtype'
      end
      generate_html_view
    end

    def register_records
      # If we have the @norecord flag set, we ignore this Activity for the
      # record collection.
      return if @norecord

      distance_record = 0.0
      distance_record_sport = nil
      # Array with popular distances (in meters) in ascending order.
      record_distances = nil
      # Speed records for popular distances (seconds hashed by distance in
      # meters)
      speed_records = {}

      segment_start_time = @fit_activity.sessions[0].start_time
      segment_start_distance = 0.0

      sport = nil
      last_timestamp = nil
      last_distance = nil

      @fit_activity.records.each do |record|
        if record.timestamp.nil?
          # All records must have a valid timestamp
          Log.warn "Found a record without a valid timestamp"
          return
        end
        if record.distance.nil?
          # All records must have a valid distance mark or the activity does
          # not qualify for a personal record.
          Log.warn "Found a record at #{record.timestamp} without a " +
                   "valid distance"
          return
        end

        unless sport
          # If the Activity has sport set to 'multisport' or 'all' we pick up
          # the sport from the FIT records. Otherwise, we just use whatever
          # sport the Activity provides.
          if @sport == 'multisport' || @sport == 'all'
            sport = record.activity_type
          else
            sport = @sport
          end
          return unless PersonalRecords::SpeedRecordDistances.include?(sport)

          record_distances = PersonalRecords::SpeedRecordDistances[sport].
            keys.sort
        end

        segment_start_distance = record.distance unless segment_start_distance
        segment_start_time = record.timestamp unless segment_start_time

        # Total distance covered in this segment so far
        segment_distance = record.distance - segment_start_distance
        # Check if we have reached the next popular distance.
        if record_distances.first &&
           segment_distance >= record_distances.first
          segment_duration = record.timestamp - segment_start_time
          # The distance may be somewhat larger than a popular distance. We
          # normalize the time to the norm distance.
          norm_duration = segment_duration / segment_distance *
            record_distances.first
          # Save the time for this distance.
          speed_records[record_distances.first] = {
            :time => norm_duration, :sport => sport
          }
          # Switch to the next popular distance.
          record_distances.shift
        end

        # We've reached the end of a segment if the sport type changes, we
        # detect a pause of more than 30 seconds or when we've reached the
        # last record.
        if (record.activity_type && sport && record.activity_type != sport) ||
           (last_timestamp && (record.timestamp - last_timestamp) > 30) ||
           record.equal?(@fit_activity.records.last)

          # Check for a total distance record
          if segment_distance > distance_record
            distance_record = segment_distance
            distance_record_sport = sport
          end

          # Prepare for the next segment in this Activity
          segment_start_distance = nil
          segment_start_time = nil
          sport = nil
        end

        last_timestamp = record.timestamp
        last_distance = record.distance
      end

      # Store the found records
      start_time = @fit_activity.sessions[0].timestamp
      if distance_record_sport
        @db.records.register_result(self, distance_record_sport,
                                    distance_record, nil, start_time)
      end
      speed_records.each do |dist, info|
        @db.records.register_result(self, info[:sport], dist, info[:time],
                                    start_time)
      end
    end

    # Return true if this activity generated any personal records.
    def has_records?
      !@db.records.activity_records(self).empty?
    end

    def generate_html_view
      @fit_activity = load_fit_file unless @fit_activity
      ActivityView.new(self, @db.cfg[:unit_system])
    end

    def activity_type
      ActivityTypes[@sport] || 'Undefined'
    end

    def activity_sub_type
      ActivitySubTypes[@sub_sport] || "Undefined #{@sub_sport}"
    end

    def distance(timestamp, unit_system)
      @fit_activity = load_fit_file unless @fit_activity

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

    private

    def load_fit_file(filter = nil)
      fit_file = File.join(@db.fit_dir, @fit_file)
      begin
        fit_activity = Fit4Ruby.read(fit_file, filter)
      rescue Fit4Ruby::Error
        Log.fatal "#{@fit_file} corrupted: #{$!}"
      end

      unless fit_activity
        Log.fatal "#{fit_file} does not contain any activity records"
      end

      fit_activity
    end

  end

end
