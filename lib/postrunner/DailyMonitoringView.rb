#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DailyMonitoringView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2016 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/View'
require 'postrunner/MonitoringStatistics'

module PostRunner

  class DailyMonitoringView < View

    attr_reader :file_name

    def initialize(db, date, monitoring_files)
      @db = db
      @ffs = db['file_store']
      views = @ffs.views
      views.current_page = nil
      @date = date
      @monitoring_files = monitoring_files

      @file_name = File.join(@db['config']['html_dir'], "#{date}.html")

      pages = PagingButtons.new([ date ])
      #pages.current_page = "#{date}.html"

      super("PostRunner Daily Monitoring: #{date}", views, pages)
      generate_html(@doc)
      write(@file_name)
    end

    private

    def generate_html(doc)
      doc.unique(:dailymonitoringview_style) {
        doc.head {
          [ 'jquery/jquery-3.5.1.min.js', 'flot/jquery.flot.js',
            'flot/jquery.flot.time.js' ].each do |js|
            doc.script({ 'language' => 'javascript',
                         'type' => 'text/javascript', 'src' => js })
          end
          doc.style(style)
        }
      }
      #doc.meta({ 'name' => 'viewport',
      #           'content' => 'width=device-width, ' +
      #                        'initial-scale=1.0, maximum-scale=1.0, ' +
      #                        'user-scalable=0' })

      body {
        doc.body {
          doc.div({ :class => 'main' }) {
            MonitoringStatistics.new(@monitoring_files).daily_html(@date, doc)
          }
        }
      }
    end

    def style
      <<EOT
body {
  font-family: verdana,arial,sans-serif;
  margin: 0px;
}
.main {
  width: 550px;
  margin: 0 auto;
}
EOT
    end

  end

end

