#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PersonalRecords.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fileutils'
require 'yaml'

require 'fit4ruby'
require 'postrunner/BackedUpFile'

module PostRunner

  class PersonalRecords

    class Record

      attr_accessor :distance, :duration, :start_time, :fit_file

      def initialize(distance, duration, start_time, fit_file)
        @distance = distance
        @duration = duration
        @start_time = start_time
        @fit_file = fit_file
      end

    end

    include Fit4Ruby::Converters

    def initialize(activities)
      @activities = activities
      @db_dir = activities.db_dir
      @records_file = File.join(@db_dir, 'records.yml')
      @records = []

      load_records
    end

    def register_result(distance, duration, start_time, fit_file)
      @records.each do |record|
        if record.duration > 0
          if duration > 0
            # This is a speed record for a popular distance.
            if distance == record.distance
              if duration < record.duration
                record.duration = duration
                record.start_time = start_time
                record.fit_file = fit_file
                Log.info "New record for #{distance} m in " +
                         "#{secsToHMS(duration)}"
                return true
              else
                # No new record for this distance.
                return false
              end
            end
          end
        else
          if distance > record.distance
            # This is a new distance record.
            record.distance = distance
            record.duration = 0
            record.start_time = start_time
            record.fit_file = fit_file
            Log.info "New distance record #{distance} m"
            return true
          else
            # No new distance record.
            return false
          end
        end
      end

      # We have not found a record.
      @records << Record.new(distance, duration, start_time, fit_file)
      if duration == 0
        Log.info "New distance record #{distance} m"
      else
        Log.info "New record for #{distance}m in #{secsToHMS(duration)}"
      end

      true
    end

    def delete_activity(fit_file)
      @records.delete_if { |r| r.fit_file == fit_file }
    end

    def sync
      save_records
    end

    def to_s
      record_names = { 1000.0 => '1 km', 1609.0 => '1 mi', 5000.0 => '5 km',
                       21097.5 => '1/2 Marathon',  42195.0 => 'Marathon' }
      t = FlexiTable.new
      t.head
      t.row([ 'Record', 'Time/Dist.', 'Avg. Pace', 'Ref.', 'Activity', 'Date' ],
            { :halign => :center })
      t.set_column_attributes([
        {},
        { :halign => :right },
        { :halign => :right },
        { :halign => :right },
        { :halign => :left },
        { :halign => :left }
      ])
      t.body
      @records.sort { |r1, r2| r1.distance <=> r2.distance }.each do |r|
        activity = @activities.activity_by_fit_file(r.fit_file)
        t.row((r.duration == 0 ?
               [ 'Longest Run', '%.1f m' % r.distance, '-' ] :
               [ record_names[r.distance], secsToHMS(r.duration),
                speedToPace(r.distance / r.duration) ]) +
              [ @activities.ref_by_fit_file(r.fit_file),
                activity.name, r.start_time.strftime("%Y-%m-%d") ])
      end
      t.to_s
    end

    private

    def load_records
      begin
        if File.exists?(@records_file)
          @records = YAML.load_file(@records_file)
        else
          Log.info "No records file found at '#{@records_file}'"
        end
      rescue StandardError
        Log.fatal "Cannot load records file '#{@records_file}': #{$!}"
      end

      unless @records.is_a?(Array)
        Log.fatal "The personal records file '#{@records_file}' is corrupted"
      end
    end

    def save_records
      begin
        BackedUpFile.open(@records_file, 'w') { |f| f.write(@records.to_yaml) }
      rescue StandardError
        Log.fatal "Cannot write records file '#{@records_file}': #{$!}"
      end
    end

  end

end

