#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivitListView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/FlexiTable'
require 'postrunner/HTMLBuilder'
require 'postrunner/ActivityLink'

module PostRunner

  # Generates a paged list of all Activity objects in the database. HTML and
  # plain text output are supported.
  class ActivityListView

    include Fit4Ruby::Converters

    def initialize(ffs)
      @ffs = ffs
      @unit_system = @ffs.store['config']['unit_system']
      @page_size = 20
      @page_no = -1
      @last_page = (@ffs.activities.length - 1) / @page_size
    end

    def update_index_pages
      0.upto(@last_page) do |page_no|
        @page_no = page_no
        generate_html_index_page(page_no)
      end
    end

    def to_s
      generate_table.to_s
    end

    private

    def generate_html_index_page(page_index)
      views = @ffs.views
      views.current_page = 'index.html'

      pages = PagingButtons.new((0..@last_page).map do |i|
        "index#{i == 0 ? '' : "-#{i}"}.html"
      end)
      pages.current_page =
        "index#{page_index == 0 ? '' : "-#{page_index}"}.html"
      @view = View.new("PostRunner Activities", views, pages)

      @view.doc.head { @view.doc.style(style) }
      body(@view.doc)

      output_file = File.join(@ffs.store['config']['html_dir'],
                              pages.current_page)
      @view.write(output_file)
    end

    def body(doc)
      @view.body {
        doc.div({ :class => 'main' }) {
          ViewFrame.new('activities', 'Activities', 900,
                        generate_table).to_html(doc)
        }
      }
    end

    def generate_table
      i = @page_no < 0 ? 0 : @page_no * @page_size
      t = FlexiTable.new
      t.head
      t.row(%w( Ref. Activity Type Start Distance Duration Speed/Pace ),
            { :halign => :left })
      t.set_column_attributes([
        { :halign => :right },
        {}, {}, {},
        { :halign => :right },
        { :halign => :right },
        { :halign => :right }
      ])
      t.body
      activities = @page_no == -1 ? @ffs.activities :
        @ffs.activities[(@page_no * @page_size)..
                        ((@page_no + 1) * @page_size - 1)]
      activities.each do |a|
        t.row([
          i += 1,
          ActivityLink.new(a, true),
          a.query('type'),
          a.query('long_date'),
          local_value(a.total_distance, 'm', '%.2f',
                      { :metric => 'km', :statute => 'mi' }),
          secsToHMS(a.total_timer_time),
          a.sport == 'running' ? pace(a.avg_speed) :
            local_value(a.avg_speed, 'm/s', '%.1f',
                        { :metric => 'km/h', :statute => 'mph' }) ])
      end

      t
    end

    def style
      <<EOT
body {
  font-family: verdana,arial,sans-serif;
  margin: 0px;
}
.main {
  text-align: center;
}
.ft_cell {
  height: 30px
}
EOT
    end

    def local_value(value, from_unit, format, units)
      to_unit = units[@unit_system]
      return '-' unless value
      value *= conversion_factor(from_unit, to_unit)
      "#{format % [value, to_unit]}"
    end

    def pace(speed)
      case @unit_system
      when :metric
        "#{speedToPace(speed)}"
      when :statute
        "#{speedToPace(speed, 1609.34)}"
      else
        Log.fatal "Unknown unit system #{@unit_system}"
      end
    end

  end

end

