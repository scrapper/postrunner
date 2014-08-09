module PostRunner

  class ChartView

    def initialize(activity, output_dir)
      @activity = activity
      @output_dir = output_dir
    end

    def generate_html
      s = <<EOT
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>Flot Examples: Basic Usage</title>
  <style>
.chart-container {
	box-sizing: border-box;
	width: 600px;
	height: 200px;
	padding: 10px 15px 15px 15px;
	margin: 15px auto 15px auto;
	border: 1px solid #ddd;
	background: #fff;
	background: linear-gradient(#f6f6f6 0, #fff 50px);
	background: -o-linear-gradient(#f6f6f6 0, #fff 50px);
	background: -ms-linear-gradient(#f6f6f6 0, #fff 50px);
	background: -moz-linear-gradient(#f6f6f6 0, #fff 50px);
	background: -webkit-linear-gradient(#f6f6f6 0, #fff 50px);
	box-shadow: 0 3px 10px rgba(0,0,0,0.15);
	-o-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
	-ms-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
	-moz-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
	-webkit-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
}
.chart-placeholder {
	width: 100%;
	height: 100%;
	font-size: 14px;
	line-height: 1.2em;
}
  </style>
	<script language="javascript" type="text/javascript"
src="js/jquery-2.1.1.js"></script>
	<script language="javascript" type="text/javascript"
src="js/flot/jquery.flot.js"></script>
  <script language="javascript" type="text/javascript"
  src="js/flot/jquery.flot.time.js"></script>
	<script type="text/javascript">

	$(function() {
EOT

      s << line_graph('pace', '#0A7BEE' )
      s << line_graph('altitude', '#5AAA44')
      s << line_graph('heart_rate', '#900000')
      s << point_graph('cadence',
                       [ [ '#EE3F2D', 151 ],
                         [ '#F79666', 163 ],
                         [ '#A0D488', 174 ],
                         [ '#96D7DE', 185 ],
                         [ '#A88BBB', nil ] ], 2)
      s << point_graph('vertical_oscillation',
                       [ [ '#A88BBB', 6.7 ],
                         [ '#96D7DE', 8.4 ],
                         [ '#A0D488', 10.1 ],
                         [ '#F79666', 11.8 ],
                         [ '#EE3F2D', nil ] ], 0.1)
      s << point_graph('stance_time',
                       [ [ '#A88BBB', 208 ],
                         [ '#96D7DE', 241 ],
                         [ '#A0D488', 273 ],
                         [ '#F79666', 305 ],
                         [ '#EE3F2D', nil ] ])

      s << <<EOT
    });
	</script>
</head>
<body>
	<div id="header">
		<h2>HR Chart</h2>
	</div>
EOT

      s << chart_div('pace', 'Pace (min/km)')
      s << chart_div('altitude', 'Elevation (m)')
      s << chart_div('heart_rate', 'Heart Rate (bpm)')
      s << chart_div('cadence', 'Run Cadence (spm)')
      s << chart_div('vertical_oscillation', 'Vertical Oscillation (cm)')
      s << chart_div('stance_time', 'Ground Contact Time (ms)')

      s << "</body>\n</html>\n"

      file_name = File.join(@output_dir, "#{@activity_id}_hr.html")
      begin
        File.write(file_name, s)
      rescue IOError
        Log.fatal "Cannot write chart view '#{file_name}': #{$!}"
      end
    end

    private

    def line_graph(field, color = nil)
      s = "var #{field}_data = [\n"

      first = true
      start_time = @activity.fit_activity.sessions[0].start_time.to_i
      @activity.fit_activity.records.each do |r|
        if first
          first = false
        else
          s << ', '
        end
        value = r.send(field)
        if field == 'pace'
          if value > 20.0
            value = nil
          else
            value = (value * 3600.0 * 1000).to_i
          end
        end
        s << "[ #{((r.timestamp.to_i - start_time) * 1000).to_i}, " +
             "#{value ? value : 'null'} ]"
      end

      s << <<"EOT"
	  	];

	  	$.plot("##{field}_chart",
             [ { data: #{field}_data,
                 #{color ? "color: \"#{color}\"," : ''}
                 lines: { show: true#{field == 'pace' ? '' : ', fill: true'} } } ],
             { xaxis: { mode: "time" }
EOT
      if field == 'pace'
        s << ", yaxis: { mode: \"time\",\n" +
             "           transform: function (v) { return -v; },\n" +
             "           inverseTransform: function (v) { return -v; } }"
      end
      s << "});\n"
    end

    def point_graph(field, colors, multiplier = 1)
      # We need to split the field values into separate data sets for each
      # color. The max value for each color determines which set a data point
      # ends up in.
      # Initialize the data sets. The key for data_sets is the corresponding
      # index in colors.
      data_sets = {}
      colors.each.with_index { |cp, i| data_sets[i] = [] }

      # Now we can split the field values into the sets.
      start_time = @activity.fit_activity.sessions[0].start_time.to_i
      @activity.fit_activity.records.each do |r|
        # Undefined values will be discarded.
        next unless (value = r.instance_variable_get('@' + field))
        value *= multiplier

        # Find the right set by looking at the maximum allowed values for each
        # color.
        colors.each.with_index do |col_max_value, i|
          col, max_value = col_max_value
          if max_value.nil? || value < max_value
            # A max_value of nil means all values allowed. The value is in the
            # allowed range for this set, so add the value as x/y pair to the
            # set.
            x_val = (r.timestamp.to_i - start_time) * 1000
            data_sets[i] << [ x_val, value ]
            # Abort the color loop since we've found the right set already.
            break
          end
        end
      end

      # Now generate the JS variable definitions for each set.
      s = ''
      data_sets.each do |index, ds|
        s << "var #{field}_data_#{index} = [\n"
        s << ds.map { |dp| "[ #{dp[0]}, #{dp[1]} ]" }.join(', ')
        s << " ];\n"
      end

      s << "$.plot(\"##{field}_chart\", [\n"
      s << data_sets.map do |index, ds|
             "{ data: #{field}_data_#{index},\n" +
             "  color: \"#{colors[index][0]}\",\n" +
             "  points: { show: true, fillColor: \"#{colors[index][0]}\", " +
             "            fill: true, radius: 2 } }"
           end.join(', ')
      s << "], { xaxis: { mode: \"time\" } });\n"

      s
    end

    def chart_div(field, title)
      "  <div id=\"#{field}_content\">\n" +
      "    <div class=\"chart-container\">\n" +
      "      <b>#{title}</b>\n" +
			"      <div id=\"#{field}_chart\" class=\"chart-placeholder\">" +
      "</div>\n" +
      "    </div>\n" +
      "  </div>\n"
    end

  end

end

