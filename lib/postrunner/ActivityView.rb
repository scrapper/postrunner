#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivityView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/HTMLBuilder'
require 'postrunner/ActivityReport'
require 'postrunner/ViewWidgets'
require 'postrunner/TrackView'
require 'postrunner/ChartView'

module PostRunner

  class ActivityView

    include ViewWidgets

    def initialize(activity, predecessor, successor)
      @activity = activity
      @predecessor = predecessor
      @successor = successor
      @output_dir = activity.html_dir
      @output_file = nil

      @doc = HTMLBuilder.new
      generate_html(@doc)
      write_file
    end

    private

    def generate_html(doc)
      @report = ActivityReport.new(@activity)
      @track_view = TrackView.new(@activity)
      @chart_view = ChartView.new(@activity)

      doc.html {
        head(doc)
        body(doc)
      }
    end

    def head(doc)
      doc.head {
        doc.meta({ 'http-equiv' => 'Content-Type',
                   'content' => 'text/html; charset=utf-8' })
        doc.meta({ 'name' => 'viewport',
                   'content' => 'width=device-width, ' +
                                'initial-scale=1.0, maximum-scale=1.0, ' +
                                'user-scalable=0' })
        doc.title("PostRunner Activity: #{@activity.name}")
        view_widgets_style(doc)
        @chart_view.head(doc)
        @track_view.head(doc)
        style(doc)
      }
    end

    def style(doc)
      doc.style(<<EOT
body {
  font-family: verdana,arial,sans-serif;
  margin: 0px;
}
.main {
  width: 1210px;
  margin: 0 auto;
}
.left_col {
  float: left;
  width: 400px;
}
.right_col {
  float: right;
  width: 600px;
}
EOT
               )
    end

    def body(doc)
      doc.body({ :onload => 'init()' }) {
        prev_page = @predecessor ? @predecessor.fit_file[0..-5] + '.html' : nil
        next_page = @successor ? @successor.fit_file[0..-5] + '.html' : nil
        titlebar(doc, nil, prev_page, 'index.html', next_page)
        # The main area with the 2 column layout.
        doc.div({ :class => 'main' }) {
          doc.div({ :class => 'left_col' }) {
            @report.to_html(doc)
            @track_view.div(doc)
          }
          doc.div({ :class => 'right_col' }) {
            @chart_view.div(doc)
          }
        }
        footer(doc)
      }
    end

    def write_file
      @output_file = File.join(@output_dir, "#{@activity.fit_file[0..-5]}.html")
      begin
        File.write(@output_file, @doc.to_html)
      rescue IOError
        Log.fatal "Cannot write activity view file '#{@output_file}: #{$!}"
      end
    end

  end

end

