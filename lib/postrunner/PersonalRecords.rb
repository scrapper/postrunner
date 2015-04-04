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

    include Fit4Ruby::Converters

    SpeedRecordDistances = {
      'cycling' => {
        5000.0 => '5 km',
        8000.0 => '8 km',
        9000.0 => '9 km',
        10000.0 => '10 km',
        20000.0 => '20 km',
        40000.0 => '40 km',
        80000.0 => '80 km',
        90000.0 => '90 km',
        12000.0 => '120 km',
        18000.0 => '180 km',
      },
      'running' => {
        1000.0 => '1 km',
        1609.0 => '1 mi',
        2000.0 => '2 km',
        3000.0 => '3 km',
        5000.0 => '5 km',
        10000.0 => '10 km',
        20000.0 => '20 km',
        30000.0 => '30 km',
        21097.5 => 'Half Marathon',
        42195.0 => 'Marathon'
      },
      'swimming' => {
        100.0 => '100 m',
        300.0 => '300 m',
        400.0 => '400 m',
        750.0 => '750 m',
        1500.0 => '1.5 km',
        1930.0 => '1.2 mi',
        3000.0 => '3 km',
        4000.0 => '4 km',
        3860.0 => '2.4 mi'
      },
      'walking' => {
        1000.0 => '1 km',
        1609.0 => '1 mi',
        5000.0 => '5 km',
        10000.0 => '10 km',
        21097.5 => 'Half Marathon',
        42195.0 => 'Marathon'
      }
    }

    class Record

      include Fit4Ruby::Converters

      attr_accessor :activity, :sport, :distance, :duration, :start_time

      def initialize(activity, sport, distance, duration, start_time)
        @activity = activity
        @sport = sport
        @distance = distance
        @duration = duration
        @start_time = start_time
      end

      def to_table_row(t)
        t.row((@duration.nil? ?
               [ 'Longest Run', '%.1f m' % @distance, '-' ] :
               [ PersonalRecords::SpeedRecordDistances[@sport][@distance],
                 secsToHMS(@duration),
                 speedToPace(@distance / @duration) ]) +
        [ @activity.db.ref_by_fit_file(@activity.fit_file),
          @activity.name, @start_time.strftime("%Y-%m-%d") ])
      end

    end

    class RecordSet

      include Fit4Ruby::Converters

      attr_reader :year

      def initialize(sport, year)
        @sport = sport
        @year = year
        @distance = nil
        @speed_records = {}
        PersonalRecords::SpeedRecordDistances[@sport].each_key do |dist|
          @speed_records[dist] = nil
        end
      end

      def register_result(result)
        if result.duration
          # We have a potential speed record for a known distance.
          unless PersonalRecords::SpeedRecordDistances[@sport].
                 include?(result.distance)
            Log.fatal "Unknown record distance #{result.distance}"
          end

          old_record = @speed_records[result.distance]
          if old_record.nil? || old_record.duration > result.duration
            @speed_records[result.distance] = result
            Log.info "New #{@year ? @year.to_s : 'all-time'} " +
                     "#{result.sport} speed record for " +
                     "#{PersonalRecords::SpeedRecordDistances[@sport][
                        result.distance]}: " +
                     "#{secsToHMS(result.duration)}"
            return true
          end
        else
          # We have a potential distance record.
          if @distance.nil? || result.distance > @distance.distance
            @distance = result
            Log.info "New #{@year ? @year.to_s : 'all-time'} " +
                     "#{result.sport} distance record: #{result.distance} m"
            return true
          end
        end

        false
      end

      def delete_activity(activity)
        if @distance && @distance.activity == activity
          @distance = nil
        end
        PersonalRecords::SpeedRecordDistances[@sport].each_key do |dist|
          if @speed_records[dist] && @speed_records[dist].activity == activity
            @speed_records[dist] = nil
          end
        end
      end

      # Return true if no Record is stored in this RecordSet object.
      def empty?
        return false if @distance
        @speed_records.each_value { |r| return false if r }

        true
      end

      # Iterator for all Record objects that are stored in this data structure.
      def each(&block)
        yield(@distance) if @distance
        @speed_records.each_value do |record|
          yield(record) if record
        end
      end

      def to_s
        return '' if empty?

        t = FlexiTable.new
        t.head
        t.row([ 'Record', 'Time/Dist.', 'Avg. Pace', 'Ref.', 'Activity',
                'Date' ],
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

        records = @speed_records.values.delete_if { |r| r.nil? }
        records << @distance if @distance

        records.sort { |r1, r2| r1.distance <=> r2.distance }.each do |r|
          r.to_table_row(t)
        end
        t.to_s + "\n"
      end

    end

    class SportRecords

      def initialize(sport)
        @sport = sport
        @all_time = RecordSet.new(@sport, nil)
        @yearly = {}
      end

      def register_result(result)
        year = result.start_time.year
        unless @yearly[year]
          @yearly[year] = RecordSet.new(@sport, year)
        end

        new_at = @all_time.register_result(result)
        new_yr = @yearly[year].register_result(result)

        new_at || new_yr
      end

      def delete_activity(activity)
        ([ @all_time ] + @yearly.values).each do |r|
          r.delete_activity(activity)
        end
      end

      # Return true if no record is stored in this SportRecords object.
      def empty?
        return false unless @all_time.empty?
        @yearly.each_value { |r| return false unless r.empty? }

        true
      end

      # Iterator for all Record objects that are stored in this data structure.
      def each(&block)
        records = @yearly.values
        records << @all_time if @all_time
        records.each { |r| r.each(&block) }
      end

      def to_s
        return '' if empty?

        str = "All-time records:\n\n#{@all_time.to_s}" unless @all_time.empty?
        @yearly.values.sort{ |r1, r2| r2.year <=> r1.year }.each do |record|
          unless record.empty?
            str += "Records of #{record.year}:\n\n#{record.to_s}"
          end
        end

        str
      end

    end

    def initialize(activities)
      @activities = activities
      @db_dir = activities.db_dir
      @records_file = File.join(@db_dir, 'records.yml')
      delete_all_records

      load_records
    end

    def register_result(activity, sport, distance, duration, start_time)
      unless @sport_records.include?(sport)
        Log.info "Ignoring records for activity type '#{sport}' in " +
                 "#{activity.fit_file}"
        return false
      end

      result = Record.new(activity, sport, distance, duration, start_time)
      @sport_records[sport].register_result(result)
    end

    def delete_all_records
      @sport_records = {}
      SpeedRecordDistances.keys.each do |sport|
        @sport_records[sport] = SportRecords.new(sport)
      end
    end

    def delete_activity(activity)
      @sport_records.each_value { |r| r.delete_activity(activity) }
    end

    def sync
      save_records
    end

    def to_s
      str = ''
      @sport_records.each do |sport, record|
        next if record.empty?
        str += "Records for activity type #{sport}:\n\n#{record.to_s}"
      end

      str
    end

    # Iterator for all Record objects that are stored in this data structure.
    def each(&block)
      @sport_records.each_value { |r| r.each(&block) }
    end

    private

    def load_records
      begin
        if File.exists?(@records_file)
          @sport_records = YAML.load_file(@records_file)
        else
          Log.info "No records file found at '#{@records_file}'"
        end
      rescue IOError
        Log.fatal "Cannot load records file '#{@records_file}': #{$!}"
      end

      unless @sport_records.is_a?(Hash)
        Log.fatal "The personal records file '#{@records_file}' is corrupted"
      end

      # Convert FIT file names into Activity references.
      each do |record|
        # Record objects can be referenced multiple times.
        if record.activity.is_a?(String)
          record.activity = @activities.activity_by_fit_file(record.activity)
        end
      end
    end

    def save_records
      # Convert Activity references into FIT file names.
      each do |record|
        # Record objects can be referenced multiple times.
        unless record.activity.is_a?(String)
          record.activity = record.activity.fit_file
        end
      end

      begin
        BackedUpFile.open(@records_file, 'w') do |f|
          f.write(@sport_records.to_yaml)
        end
      rescue IOError
        Log.fatal "Cannot write records file '#{@records_file}': #{$!}"
      end
    end

  end

end

