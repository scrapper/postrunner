#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = TrackView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/ViewFrame'

module PostRunner

  # A TrackView object uses OpenLayers to draw a map with the waypoints of the
  # activity. Lap end are marked with enumerated lap markers.
  class TrackView

    # Create a new TrackView object for a given Activity.
    # @param activity [Activity] The activity to render
    def initialize(activity)
      @activity = activity
      @session = @activity.fit_activity.sessions[0]
      @has_geo_data = @session.has_geo_data?
    end

    # Render the map widget with the track and marker overlay as HTML code.
    # @param doc [HTMLBuilder] HTML document to add to.
    def to_html(doc)
      return unless @has_geo_data

      doc.head {
        doc.unique(:trackview_style) {
          doc.style(style)
          doc.link({ 'rel' => 'stylesheet',
                     'href' => 'openlayers/ol.css',
                     'type' => 'text/css' })
          doc.script({ 'src' => 'openlayers/ol.js' })
          doc.script({ 'src' => 'postrunner/trackview.js' })
        }
        doc.script(java_script)
      }

      ViewFrame.new('Map', 600) {
        doc.div({ 'id' => 'map', 'class' => 'trackmap' })
      }.to_html(doc)
    end

    private

    def style
      <<EOT
.olControlAttribution {
    bottom: 5px;
}

.trackmap {
  width: 565px;
  height: 400px;
  border: 2px solid #545454;
}
EOT
    end

    def java_script
      center_long = @session.swc_long +
        (@session.nec_long - @session.swc_long) / 2.0
      center_lat = @session.swc_lat +
        (@session.nec_lat - @session.swc_lat) / 2.0

      <<"EOT"
#{track_points}
#{lap_markers}
function init() {
  pr_trackview_init(#{center_long}, #{center_lat});
}
EOT
    end

    # Generate a javascript variable with an Array with the coordinates of the
    # track points. Each coordinate is an Array with a longitude and latitude
    # in EPSG:4326. Generate a javascript variable with an Array of track
    # points.
    def track_points
      points = []
      @activity.fit_activity.sessions.map do |session|
        session.records.map do |record|
          long = record.position_long
          lat = record.position_lat
          next unless long && lat

          points << "[ #{long}, #{lat} ]"
        end
      end

      "var pr_track_points = [\n" +
      points.join(', ') +
      "\n];\n"
    end

    # Generate a javascript variable with an Array with the coordinates of the
    # start point and the lap end points. Each coordinate is an Array with a
    # longitude and latitude in EPSG:4326.
    def lap_markers
      "var pr_lap_markers = [\n" +
        "[ #{@session.start_position_long}," +
        " #{@session.start_position_lat} ], " +
        @activity.fit_activity.laps.map do |lap|
          "[ #{lap.end_position_long}, #{lap.end_position_lat} ]"
        end.join(', ') +
        "\n];\n"
    end

  end

end

