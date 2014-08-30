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
require 'postrunner/ViewWidgets'

module PostRunner

  class ActivityListView

    class ActivityLink

      def initialize(activity)
        @activity = activity
      end

      def to_html(doc)
        doc.a(@activity.name, { :class => 'activity_link',
                                :href => @activity.fit_file[0..-5] + '.html' })
      end

      def to_s
        @activity.name[0..19]
      end

    end

    include Fit4Ruby::Converters
    include ViewWidgets

    def initialize(db)
      @db = db
      @unit_system = @db.cfg[:unit_system]
      @page_size = 20
      @page_no = -1
      @last_page = (@db.activities.length - 1) / @page_size
    end

    def update_html_index
      0.upto(@last_page) do |page_no|
        @page_no = page_no
        generate_html_index_page
      end
    end

    def to_html(doc)
      generate_table.to_html(doc)
    end

    def to_s
      generate_table.to_s
    end

    private

    def generate_html_index_page
      doc = HTMLBuilder.new

      doc.html {
        head(doc)
        body(doc)
      }

      write_file(doc)
    end

    def head(doc)
      doc.head {
        doc.meta({ 'http-equiv' => 'Content-Type',
                   'content' => 'text/html; charset=utf-8' })
        doc.title("PostRunner Activities")
        style(doc)
      }
    end

    def style(doc)
      view_widgets_style(doc)
      doc.style(<<EOT
body {
  font-family: verdana,arial,sans-serif;
  margin: 0px;
}
.main {
  text-align: center;
}
.widget_frame {
  width: 900px;
}
.activity_link {
  padding: 0px 3px 0px 3px;
}
.ft_cell {
  height: 30px
}
EOT
               )
    end

    def body(doc)
      doc.body {
        first_page = @page_no == 0 ? nil: 'index.html'
        prev_page = @page_no == 0 ? nil :
                    @page_no == 1 ? 'index.html' :
                                    "index#{@page_no - 1}.html"
        prev_page = @page_no == 0 ? nil :
                    @page_no == 1 ? 'index.html' :
                                    "index#{@page_no - 1}.html"
        next_page = @page_no < @last_page ? "index#{@page_no + 1}.html" : nil
        last_page = @page_no == @last_page ? nil : "index#{@last_page}.html"
        titlebar(doc, first_page, prev_page, nil, next_page, last_page)

        doc.div({ :class => 'main' }) {
          frame(doc, 'Activities') {
            generate_table.to_html(doc)
          }
        }
        footer(doc)
      }
    end

    def generate_table
      i = @page_no < 0 ? 0 : @page_no * @page_size
      t = FlexiTable.new
      t.head
      t.row(%w( Ref. Activity Start Distance Duration Speed/Pace ),
            { :halign => :left })
      t.set_column_attributes([
        { :halign => :right },
        {}, {},
        { :halign => :right },
        { :halign => :right },
        { :halign => :right }
      ])
      t.body
      activities = @page_no == -1 ? @db.activities :
        @db.activities[(@page_no * @page_size)..
                       ((@page_no + 1) * @page_size - 1)]
      activities.each do |a|
        t.row([
          i += 1,
          ActivityLink.new(a),
          a.timestamp.strftime("%a, %Y %b %d %H:%M"),
          local_value(a.total_distance, 'm', '%.2f',
                      { :metric => 'km', :statute => 'mi' }),
          secsToHMS(a.total_timer_time),
          a.sport == 'running' ? pace(a.avg_speed) :
            local_value(a.avg_speed, 'm/s', '%.1f',
                        { :metric => 'km/h', :statute => 'mph' }) ])
      end

      t
    end

    def write_file(doc)
      output_file = File.join(@db.html_dir,
                              "index#{@page_no == 0 ? '' : @page_no}.html")
      begin
        File.write(output_file, doc.to_html)
      rescue IOError
        Log.fatal "Cannot write activity index file '#{output_file}: #{$!}"
      end
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

