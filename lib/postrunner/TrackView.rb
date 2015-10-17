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

  class TrackView

    def initialize(activity)
      @activity = activity
      @session = @activity.fit_activity.sessions[0]
      @has_geo_data = @session.has_geo_data?
    end

    def to_html(doc)
      return unless @has_geo_data

      doc.head {
        doc.unique(:trackview_style) {
          doc.style(style)
          doc.link({ 'rel' => 'stylesheet',
                     'href' => 'openlayers/ol.css',
                     'type' => 'text/css' })
          doc.script({ 'src' => 'openlayers/ol.js' })
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
      js = <<EOT
function init() {
EOT

      center_long = @session.swc_long +
        (@session.nec_long - @session.swc_long) / 2.0
      center_lat = @session.swc_lat +
        (@session.nec_lat - @session.swc_lat) / 2.0

      track_points(js)
      lap_markers(js)
      js << <<"EOT"
  lm_w = 40;
  lm_h = 100;
  var map = new ol.Map({
    view: new ol.View({
      center: ol.proj.transform([ #{center_long}, #{center_lat} ],
                                'EPSG:4326', 'EPSG:900913'),
      zoom: 14,
    }),
    layers: [
      new ol.layer.Tile({
        source: new ol.source.MapQuest({layer: 'osm'})
      }),
      new ol.layer.Vector({
        source: source_vector = new ol.source.Vector({
          features: [
            new ol.Feature({
              geometry: new ol.geom.LineString(track_points)
            })
          ]
        }),
        style: [
          new ol.style.Style({
            stroke: new ol.style.Stroke({
              color: 'red',
              width: 5
            }),
            fill: new ol.style.Fill({
              color: 'white'
            })
          })
        ]
      }),
      new ol.layer.Vector({
        source: lap_marker_source = new ol.source.Vector(),
        style: function(feature, resolution) {
          return [
            new ol.style.Style({
              stroke: new ol.style.Stroke({
                color: 'black',
                width: 2
              }),
              fill: new ol.style.Fill({
                color: 'red'
              }),
              text: new ol.style.Text({
                font: '' + (lm_w / resolution) + 'px helvetica,sans-serif',
                text: resolution < (lm_w / 8.0) ? feature.get('name') : '',
                fill: new ol.style.Fill({
                  color: 'black'
                })
              })
            })
          ];
        }
      })
    ],
    target: "map"
  });
  for (var i in lap_markers) {
    x = lap_markers[i][0];
    y = lap_markers[i][1];
    lap_marker_source.addFeature(
      new ol.Feature({
        geometry: new ol.geom.Polygon([[[ x - lm_w, y + lm_h ],
                                        [ x, y ],
                                        [ x + lm_w, y + lm_h ],
                                        [ x - lm_w, y + lm_h ]]])
      })
    );
    lap_marker_source.addFeature(
      new ol.Feature({
        geometry: new ol.geom.Circle([ x, y + lm_h + 3 ], lm_w),
        name: (i == 0 ? 'S' : i == lap_markers.length - 1 ? 'F' : i),
      })
    );
  };
};
EOT

      js
    end

    def track_points(script)
      first = true
      script << "var track_points = [\n"

      @activity.fit_activity.sessions.each do |session|
        session.records.each do |record|
          long = record.position_long
          lat = record.position_lat
          next unless long && lat

          if first
            first = false
          else
            script << ', '
          end
          script << "[ #{long}, #{lat} ]"
        end
      end
      script << <<"EOT"
];
track_points.forEach(
  function(coords, i, arr) {
    arr[i] = ol.proj.transform(coords, 'EPSG:4326', 'EPSG:900913');
  }
);
EOT
    end

    def lap_markers(script)
      script << "var lap_markers = [\n" +
        "[ #{@session.start_position_long}," +
         " #{@session.start_position_lat} ], "
      @activity.fit_activity.laps.each do |lap|
        script << "[ #{lap.end_position_long}, #{lap.end_position_lat} ], "
      end
      last_lap = @activity.fit_activity.laps[-1]
      script << "[ #{last_lap.end_position_long},
                   #{last_lap.end_position_lat} ]"
      script << <<"EOT"
];
lap_markers.forEach(
  function(coords, i, arr) {
    arr[i] = ol.proj.transform(coords, 'EPSG:4326', 'EPSG:900913');
  }
);
EOT

    end

  end

end

