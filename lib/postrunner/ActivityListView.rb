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
    end

    def update_html_index
      doc = HTMLBuilder.new

      doc.html {
        head(doc)
        body(doc)
      }

      write_file(doc)
    end

    def to_html(doc)
      generate_table.to_html(doc)
    end

    def to_s
      generate_table.to_s
    end

    private

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
EOT
               )
    end

    def body(doc)
      doc.body {
        titlebar(doc)
        doc.div({ :class => 'main' }) {
          frame(doc, 'Activities') {
            generate_table.to_html(doc)
          }
        }
        footer(doc)
      }
    end

    def generate_table
      i = 0
      t = FlexiTable.new
      t.head
      t.row(%w( Ref. Activity Start Distance Duration Pace ),
            { :halign => :left })
      t.set_column_attributes([
        { :halign => :right },
        {}, {},
        { :halign => :right },
        { :halign => :right },
        { :halign => :right }
      ])
      t.body
      @db.activities.each do |a|
        t.row([
          i += 1,
          ActivityLink.new(a),
          a.timestamp.strftime("%a, %Y %b %d %H:%M"),
          "%.2f" % (a.total_distance / 1000),
          secsToHMS(a.total_timer_time),
          speedToPace(a.avg_speed) ])
      end

      t
    end

    def write_file(doc)
      output_file = File.join(@db.html_dir, 'index.html')
      begin
        File.write(output_file, doc.to_html)
      rescue IOError
        Log.fatal "Cannot write activity index file '#{output_file}: #{$!}"
      end
    end
  end

end

