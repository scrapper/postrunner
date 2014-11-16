#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Activity.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/ActivitySummary'
require 'postrunner/ActivityView'

module PostRunner

  class Activity

    attr_reader :db, :fit_file, :name, :fit_activity, :html_dir, :html_file

    # This is a list of variables that provide data from the fit file. To
    # speed up access to it, we cache the data in the activity database.
    @@CachedActivityValues = %w( sport timestamp total_distance
                                 total_timer_time avg_speed )
    # We also store some additional information in the archive index.
    @@CachedAttributes = @@CachedActivityValues + %w( fit_file name )

    @@ActivityTypes = {
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
      @html_dir = File.join(@db.db_dir, 'html')
      @html_file = File.join(@html_dir, "#{@fit_file[0..-5]}.html")

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
      @fit_activity = load_fit_file
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

    def show
      generate_html_view #unless File.exists?(@html_file)

      @db.show_in_browser(@html_file)
    end

    def summary
      @fit_activity = load_fit_file unless @fit_activity
      puts ActivitySummary.new(@fit_activity, name, @db.cfg[:unit_system]).to_s
    end

    def rename(name)
      @name = name
      generate_html_view
    end

    def register_records(db)
      @fit_activity.personal_records.each do |r|
        if r.longest_distance == 1
          # In case longest_distance is 1 the distance is stored in the
          # duration field in 10-th of meters.
          db.register_result(r.duration * 10.0 , 0, r.start_time, @fit_file)
        else
          db.register_result(r.distance, r.duration, r.start_time, @fit_file)
        end
      end
    end

    def generate_html_view
      @fit_activity = load_fit_file unless @fit_activity
      ActivityView.new(self, @db.cfg[:unit_system], @db.predecessor(self),
                       @db.successor(self))
    end

    def activity_type
      @@ActivityTypes[@sport] || 'Undefined'
    end

    private

    def load_fit_file(filter = nil)
      fit_file = File.join(@db.fit_dir, @fit_file)
      begin
        return Fit4Ruby.read(fit_file, filter)
      rescue Fit4Ruby::Error
        Log.fatal $!
      end
    end

  end

end

