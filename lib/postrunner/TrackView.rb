require 'fit4ruby'

require 'postrunner/ViewWidgets'

module PostRunner

  class TrackView

    include ViewWidgets

    def initialize(activity)
      @activity = activity
    end

    def head(doc)
      doc.link({ 'rel' => 'stylesheet',
                 'href' => 'openlayers/theme/default/style.css',
                 'type' => 'text/css' })
      doc.style(style)
      doc.script({ 'src' => 'openlayers/OpenLayers.js' })
      doc.script(java_script)
    end

    def div(doc)
      frame(doc, 'Map') {
        doc.div({ 'id' => 'map', 'class' => 'trackmap' })
      }
    end

    private

    def style
      <<EOT
.olControlAttribution {
    bottom: 5px;
}

.trackmap {
  width: 570px;
  height: 400px;
  border: 2px solid #545454;
}
EOT
    end

    def java_script
      js = <<EOT
var map;

function init() {
  var mercator = new OpenLayers.Projection("EPSG:900913");
  var geographic = new OpenLayers.Projection("EPSG:4326");
EOT

      session = @activity.fit_activity.sessions[0]
      center_long = session.swc_long +
        (session.nec_long - session.swc_long) / 2.0
      center_lat = session.swc_lat +
        (session.nec_lat - session.swc_lat) / 2.0
      last_lap = @activity.fit_activity.laps[-1]

      js << <<EOT
  map = new OpenLayers.Map({
      div: "map",
      projection: mercator,
      layers: [ new OpenLayers.Layer.OSM() ],
      center: new OpenLayers.LonLat(#{center_long}, #{center_lat}).transform(geographic, mercator),
      zoom: 13
  });
EOT
      js << <<"EOT"
  track_layer = new OpenLayers.Layer.PointTrack("Track",
    {style: {strokeColor: '#FF0000',  strokeWidth: 5}});
  map.addLayer(track_layer);
  track_layer.addNodes([
EOT
      track_points(js)

      js << <<"EOT"
    ]);
  var markers = new OpenLayers.Layer.Markers( "Markers" );
  map.addLayer(markers);

  var size = new OpenLayers.Size(21,25);
  var offset = new OpenLayers.Pixel(-(size.w/2), -size.h);
EOT
      set_marker(js, 'marker-green', session.start_position_long,
                 session.start_position_lat)
      @activity.fit_activity.laps[0..-2].each do |lap|
        set_marker(js, 'marker-blue',
                   lap.end_position_long, lap.end_position_lat)
      end
      set_marker(js, 'marker',
                 last_lap.end_position_long, last_lap.end_position_lat)
      js << "\n};"

      js
    end

    def track_points(script)
      first = true
      @activity.fit_activity.sessions.each do |session|
        session.laps.each do |lap|
          lap.records.each do |record|
            long = record.position_long
            lat = record.position_lat
            if first
              first = false
            else
              script << ","
            end
            script << <<"EOT"
new OpenLayers.Feature.Vector(new OpenLayers.Geometry.Point(#{long}, #{lat}).transform(geographic, mercator))
EOT
          end
        end
      end
    end

    def set_marker(script, type, long, lat)
      script << <<"EOT"
    markers.addMarker(new OpenLayers.Marker(new OpenLayers.LonLat(#{long},#{lat}).transform(geographic, mercator),new OpenLayers.Icon('openlayers/img/#{type}.png',size,offset)));
EOT
    end

  end

end

