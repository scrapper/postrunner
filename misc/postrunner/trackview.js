/*
 * TrackView.js -- PostRunner - Manage the data from your Garmin sport devices.
 *
 * Copyright (c) 2014, 2015, 2016 by Chris Schlaeger <cs@taskjuggler.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of version 2 of the GNU General Public License as
 * published by the Free Software Foundation.
 */

var pr_trackview_init = function(center_long, center_lat) {
  lm_w = 40;
  lm_h = 100;

  pr_transformer = function(coords, i, arr) {
    arr[i] = ol.proj.transform(coords, 'EPSG:4326', 'EPSG:900913');
  };

  pr_track_points.forEach(pr_transformer);
  pr_lap_markers.forEach(pr_transformer);

  var map = new ol.Map({
    view: new ol.View({
      center: ol.proj.transform([ center_long, center_lat ],
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
              geometry: new ol.geom.LineString(pr_track_points)
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
                color: feature.get('color')
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
  for (var i in pr_lap_markers) {
    x = pr_lap_markers[i][0];
    y = pr_lap_markers[i][1];
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
        geometry: new ol.geom.Circle([ x, y + lm_h ], lm_w),
        name: (i == 0 ? 'S' : i == pr_lap_markers.length - 1 ? 'F' : i),
        color: (i == 0 ? 'green' :
		         i == pr_lap_markers.length - 1 ? 'red' : 'yellow'),
      })
    );
  };
};

