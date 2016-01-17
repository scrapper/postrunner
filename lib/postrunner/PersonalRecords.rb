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

require 'postrunner/RecordListPageView'

module PostRunner

  # The PersonalRecords class stores the various records. Records are grouped
  # by specific year or all-time records.
  class PersonalRecords < PEROBS::Object

    include Fit4Ruby::Converters

    # List of popular distances for each sport.
    SpeedRecordDistances = {
      'cycling' => {
        1000.0 => '1 km',
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
        400.0 => '400 m',
        500.0 => '500 m',
        800.0 => '800 m',
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
        500.0 => '500 m',
        1000.0 => '1 km',
        1609.0 => '1 mi',
        5000.0 => '5 km',
        10000.0 => '10 km',
        21097.5 => 'Half Marathon',
        42195.0 => 'Marathon'
      }
    }

    po_attr :sport_records

    class ActivityResult

      attr_reader :activity, :sport, :distance, :duration, :start_time

      def initialize(activity, sport, distance, duration, start_time)
        @activity = activity
        @sport = sport
        @distance = distance
        @duration = duration
        @start_time = start_time
      end

    end

    # The Record class stores a single speed or longest distance record. It
    # also stores a reference to the Activity that contains the record.
    class Record < PEROBS::Object

      include Fit4Ruby::Converters

      po_attr :activity, :sport, :distance, :duration, :start_time

      def initialize(p, result)
        super(p)

        self.activity = result.activity
        self.sport = result.sport
        self.distance = result.distance
        self.duration = result.duration
        self.start_time = result.start_time
      end

      def to_table_row(t)
        t.row((@duration.nil? ?
               [ 'Longest Distance', '%.3f km' % (@distance / 1000.0), '-' ] :
               [ PersonalRecords::SpeedRecordDistances[@sport][@distance],
                 secsToHMS(@duration),
                 speedToPace(@distance / @duration) ]) +
              [ @store['file_store'].ref_by_activity(@activity),
                ActivityLink.new(@activity, false),
                @start_time.strftime("%Y-%m-%d") ])
      end

    end

    class RecordSet < PEROBS::Object

      include Fit4Ruby::Converters

      po_attr :sport, :year, :distance_record, :speed_records

      def initialize(p, sport, year)
        super(p)

        self.sport = sport
        self.year = year
        self.distance_record = nil
        self.speed_records = @store.new(PEROBS::Hash)
        if sport
          PersonalRecords::SpeedRecordDistances[sport].each_key do |dist|
            @speed_records[dist.to_s] = nil
          end
        end
      end

      def register_result(result)
        if result.duration
          # We have a potential speed record for a known distance.
          unless PersonalRecords::SpeedRecordDistances[@sport].
                 include?(result.distance)
            Log.fatal "Unknown record distance #{result.distance}"
          end

          old_record = @speed_records[result.distance.to_s]
          if old_record.nil? || old_record.duration > result.duration
            @speed_records[result.distance.to_s] = @store.new(Record, result)
            Log.info "New #{@year ? @year.to_s : 'all-time'} " +
                     "#{result.sport} speed record for " +
                     "#{PersonalRecords::SpeedRecordDistances[@sport][
                        result.distance]}: " +
                     "#{secsToHMS(result.duration)}"
            return true
          end
        else
          # We have a potential distance record.
          if @distance_record.nil? ||
             @distance_record.distance < result.distance
            self.distance_record = @store.new(Record, result)
            raise RuntimeError if @distance_record.is_a?(String)
            Log.info "New #{@year ? @year.to_s : 'all-time'} " +
                     "#{result.sport} distance record: #{result.distance} m"
            return true
          end
        end

        false
      end

      def delete_activity(activity)
        record_deleted = false
        if @distance_record && @distance_record.activity == activity
          self.distance_record = nil
          record_deleted = true
        end
        PersonalRecords::SpeedRecordDistances[@sport].each_key do |dist|
          dist = dist.to_s
          if @speed_records[dist] && @speed_records[dist].activity == activity
            @speed_records[dist] = nil
            record_deleted = true
          end
        end

        record_deleted
      end

      # Return true if no Record is stored in this RecordSet object.
      def empty?
        return false if @distance_record
        @speed_records.each_value { |r| return false if r }

        true
      end

      # Iterator for all Record objects that are stored in this data structure.
      def each(&block)
        yield(@distance_record) if @distance_record
        @speed_records.each_value do |record|
          yield(record) if record
        end
      end

      def to_s
        return '' if empty?

        generate_table.to_s + "\n"
      end

      def to_html(doc)
        generate_table.to_html(doc)
      end

      private

      def generate_table
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

        records = @speed_records.values.delete_if { |r| r.nil? }.
                  sort { |r1, r2| r1.distance <=> r2.distance }
        records << @distance_record if @distance_record

        records.each { |r| r.to_table_row(t) }

        t
      end

    end

    class SportRecords < PEROBS::Object

      po_attr :sport, :all_time, :yearly

      def initialize(p, sport)
        super(p)

        self.sport = sport
        self.all_time = @store.new(RecordSet, sport, nil)
        self.yearly = @store.new(PEROBS::Hash)
      end

      def register_result(result)
        year = result.start_time.year.to_s
        unless @yearly[year]
          @yearly[year] = @store.new(RecordSet, @sport, year)
        end

        new_at = @all_time.register_result(result)
        new_yr = @yearly[year].register_result(result)

        new_at || new_yr
      end

      def delete_activity(activity)
        record_deleted = false
        ([ @all_time ] + @yearly.values).each do |r|
          record_deleted = true if r.delete_activity(activity)
        end

        record_deleted
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

      def to_html(doc)
        return nil if empty?

        doc.div {
          doc.h3('All-time records')
          @all_time.to_html(doc)
          @yearly.values.sort do |r1, r2|
            r2.year.to_i <=> r1.year.to_i
          end.each do |record|
            unless record.empty?
              doc.h3("Records of #{record.year}")
              record.to_html(doc)
            end
          end
        }
      end

    end

    def initialize(p)
      super(p)

      self.sport_records = @store.new(PEROBS::Hash)
      delete_all_records
    end

    def scan_activity_for_records(activity, report_update_requested = false)
      # If we have the @norecord flag set, we ignore this Activity for the
      # record collection.
      return if activity.norecord

      activity.load_fit_file

      distance_record = 0.0
      distance_record_sport = nil
      # Array with popular distances (in meters) in ascending order.
      record_distances = nil
      # Speed records for popular distances (seconds hashed by distance in
      # meters)
      speed_records = {}

      segment_start_time = activity.fit_activity.sessions[0].start_time
      segment_start_distance = 0.0

      sport = nil
      last_timestamp = nil
      last_distance = nil

      activity.fit_activity.records.each do |record|
        if record.distance.nil?
          # All records must have a valid distance mark or the activity does
          # not qualify for a personal record.
          Log.warn "Found a record without a valid distance"
          return
        end
        if record.timestamp.nil?
          Log.warn "Found a record without a valid timestamp"
          return
        end

        unless sport
          # If the Activity has sport set to 'multisport' or 'all' we pick up
          # the sport from the FIT records. Otherwise, we just use whatever
          # sport the Activity provides.
          if activity.sport == 'multisport' || activity.sport == 'all'
            sport = record.activity_type
          else
            sport = activity.sport
          end
          return unless SpeedRecordDistances.include?(sport)

          record_distances = SpeedRecordDistances[sport].
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
           record.equal?(activity.fit_activity.records.last)

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
      start_time = activity.fit_activity.sessions[0].timestamp
      update_reports = false
      if distance_record_sport
        if register_result(activity, distance_record_sport, distance_record,
                           nil, start_time)
          update_reports = true
        end
      end
      speed_records.each do |dist, info|
        if register_result(activity, info[:sport], dist, info[:time],
                           start_time)
          update_reports = true
        end
      end

      generate_html_reports if update_reports && report_update_requested
    end

    def register_result(activity, sport, distance, duration, start_time)
      unless @sport_records.include?(sport)
        Log.info "Ignoring records for activity type '#{sport}' in " +
                 "#{activity.fit_file_name}"
        return false
      end

      result = ActivityResult.new(activity, sport, distance, duration,
                                  start_time)
      @sport_records[sport].register_result(result)
    end

    def delete_all_records
      @sport_records.clear
      SpeedRecordDistances.keys.each do |sport|
        @sport_records[sport] = @store.new(SportRecords, sport)
      end
    end

    def delete_activity(activity)
      record_deleted = false
      @sport_records.each_value do |r|
        record_deleted = true if r.delete_activity(activity)
      end

      record_deleted
    end

    def generate_html_reports
      non_empty_records = @sport_records.select { |s, r| !r.empty? }
      max = non_empty_records.length
      i = 0
      non_empty_records.each do |sport, record|
        output_file = File.join(@store['config']['html_dir'],
                                "records-#{i}.html")
        RecordListPageView.new(@store['file_store'], record, max, i).
                               write(output_file)
        i += 1
      end
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

    # Return an Array of all the records associated with the given Activity.
    def activity_records(activity)
      records = []
      each do |record|
        if record.activity.equal?(activity)
          records << record
        end
      end

      records
    end

  end

end

