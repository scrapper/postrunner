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

require 'postrunner/ActivityReport'
require 'postrunner/ActivityView'

module PostRunner

  class Activity

    attr_reader :db, :fit_file, :name, :fit_activity, :html_dir, :html_file

    # This is a list of variables that provide data from the fit file. To
    # speed up access to it, we cache the data in the activity database.
    @@CachedVariables = %w( timestamp total_distance total_timer_time
                            avg_speed )

    def initialize(db, fit_file, fit_activity, name = nil)
      @fit_file = fit_file
      @fit_activity = fit_activity
      @name = name || fit_file
      late_init(db)

      @@CachedVariables.each do |v|
        v_str = "@#{v}"
        instance_variable_set(v_str, fit_activity.send(v))
        self.class.send(:attr_reader, v.to_sym)
      end
      # Generate HTML file for this activity.
      generate_html_view
    end

    def late_init(db)
      @db = db
      @html_dir = File.join(@db.db_dir, 'html')
      @html_file = File.join(@html_dir, "#{@fit_file[0..-5]}.html")
    end

    def check
      # Re-generate the HTML file for this activity
      generate_html_view
      Log.info "FIT file #{@fit_file} is OK"
    end

    def dump(filter)
      @fit_activity = load_fit_file(filter)
    end

    def yaml_initialize(tag, value)
      # Create attr_readers for cached variables.
      @@CachedVariables.each { |v| self.class.send(:attr_reader, v.to_sym) }

      # Load all attributes and assign them to instance variables.
      value.each do |a, v|
        instance_variable_set("@" + a, v)
      end
      # Use the FIT file name as activity name if none has been set yet.
      @name = @fit_file unless @name
    end

    def encode_with(coder)
      attr_ignore = %w( @db @fit_activity )

      instance_variables.each do |v|
        v = v.to_s
        next if attr_ignore.include?(v)

        coder[v[1..-1]] = instance_variable_get(v)
      end
    end

    def show
      generate_html_view #unless File.exists?(@html_file)

      @db.show_in_browser(@html_file)
    end

    def summary
      @fit_activity = load_fit_file unless @fit_activity
      puts ActivityReport.new(self).to_s
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
      ActivityView.new(self, @db.predecessor(self), @db.successor(self))
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

