require 'fit4ruby'

module PostRunner

  class TrackView

    def initialize(activity, output_dir)
      @activity = activity
      @activity_id = activity.fit_file[0..-4]
      @output_dir = output_dir
    end

    def generate_html
      s = <<EOT
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width,
     initial-scale=1.0, maximum-scale=1.0, user-scalable=0">
    <meta name="apple-mobile-web-app-capable" content="yes">
EOT
      s << "<title>PostRunner: #{@activity.name}</title>\n"
      s << <<EOT
    <link rel="stylesheet" href="js/theme/default/style.css" type="text/css">
    <link rel="stylesheet" href="js/theme/default/google.css" type="text/css">
    <style>
.olControlAttribution {
    bottom: 5px;
}

.trackmap {
    width: 600px;
    height: 400px;
    border: 1px solid #ccc;
}
    </style>
    <script src="js/OpenLayers.js"></script>
    <script>
EOT
      s << js_file

      s << <<EOT
    </script>
  </head>
  <body onload="init()">
EOT
      s << "<h1 id=\"title\">PostRunner: #{@activity.name}</h1>\n"
      s << <<EOT
    <p id="shortdesc">
      Map view of a captured track.
    </p>
    <div id="map" class="trackmap"></div>
  </body>
</html>
EOT
      file_name = File.join(@output_dir, "#{@activity_id}.html")
      begin
        File.write(file_name, s)
      rescue IOError
        Log.fatal "Cannot write TrackViewer file '#{file_name}': #{$!}"
      end
    end

    private

    def js_file
      script = <<EOT
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

      script << <<EOT
  map = new OpenLayers.Map({
      div: "map",
      projection: mercator,
      layers: [ new OpenLayers.Layer.OSM() ],
      center: new OpenLayers.LonLat(#{center_long}, #{center_lat}).transform(geographic, mercator),
      zoom: 13
  });
EOT
      script << <<"EOT"
  track_layer = new OpenLayers.Layer.PointTrack("Track",
    {style: {strokeColor: '#FF0000',  strokeWidth: 5}});
  map.addLayer(track_layer);
  track_layer.addNodes([
EOT
      track_points(script)

      script << <<"EOT"
    ]);
  var markers = new OpenLayers.Layer.Markers( "Markers" );
  map.addLayer(markers);

  var size = new OpenLayers.Size(21,25);
  var offset = new OpenLayers.Pixel(-(size.w/2), -size.h);
EOT
      set_marker(script, 'marker-green', session.start_position_long,
                 session.start_position_lat)
      @activity.fit_activity.laps[0..-2].each do |lap|
        set_marker(script, 'marker-blue',
                   lap.end_position_long, lap.end_position_lat)
      end
      set_marker(script, 'marker',
                 last_lap.end_position_long, last_lap.end_position_lat)
      script << "\n};"

      script
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
    markers.addMarker(new OpenLayers.Marker(new OpenLayers.LonLat(#{long},#{lat}).transform(geographic, mercator),new OpenLayers.Icon('js/img/#{type}.png',size,offset)));
EOT
    end

  end

end

