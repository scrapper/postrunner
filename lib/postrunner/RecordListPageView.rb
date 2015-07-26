#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RecordListPageView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/FlexiTable'
require 'postrunner/View'
require 'postrunner/ViewFrame'
require 'postrunner/ViewButtons'
require 'postrunner/PagingButtons'

module PostRunner

  # Generates an HTML page with all personal records for a particular sport
  # type.
  class RecordListPageView < View

    include Fit4Ruby::Converters

    # Create a RecordListPageView object.
    # @param db [ActivityDB] Activity database
    # @param records [PersonalRecords] Database with personal records
    # @param page_count [Fixnum] Number of total pages
    # @param page_index [Fixnum] Index of the page
    def initialize(db, records, page_count, page_index)
      @db = db
      @unit_system = @db.cfg[:unit_system]
      @records = records

      views = @db.views
      views.current_page = "records-0.html"

      pages = PagingButtons.new((0..(page_count - 1)).map do |i|
        "records-#{i}.html"
      end)
      pages.current_page =
        "records-#{page_index}.html"

      @sport_name = Activity::ActivityTypes[@records.sport]
      super("#{@sport_name} Records", views, pages)

      body {
        frame_width = 800

        @doc.div({ :class => 'main' }) {
          ViewFrame.new("All-time #{@sport_name} Records",
                        frame_width, @records.all_time).to_html(@doc)

          @records.yearly.sort{ |y1, y2| y2[0] <=> y1[0] }.
                          each do |year, record|
            next if record.empty?
            ViewFrame.new("#{year} #{@sport_name} Records",
                          frame_width, record).to_html(@doc)
          end
        }
      }
    end

  end

end
