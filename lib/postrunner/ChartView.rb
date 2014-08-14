require 'postrunner/ViewWidgets'

module PostRunner

  class ChartView

    include ViewWidgets

    def initialize(activity)
      @activity = activity
      @empty_charts = {}
    end

    def head(doc)
      [ 'jquery/jquery-2.1.1.min.js', 'flot/jquery.flot.js',
        'flot/jquery.flot.time.js' ].each do |js|
        doc.script({ 'language' => 'javascript', 'type' => 'text/javascript',
                     'src' => js })
      end
      doc.style(style)
      doc.script(java_script)
    end

    def div(doc)
      chart_div(doc, 'pace', 'Pace (min/km)')
      chart_div(doc, 'altitude', 'Elevation (m)')
      chart_div(doc, 'heart_rate', 'Heart Rate (bpm)')
      chart_div(doc, 'cadence', 'Run Cadence (spm)')
      chart_div(doc, 'vertical_oscillation', 'Vertical Oscillation (cm)')
      chart_div(doc, 'stance_time', 'Ground Contact Time (ms)')
    end

    private

    def style
      <<EOT
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
	width: 570px;
	height: 200px;
	font-size: 14px;
	line-height: 1.2em;
}
EOT
    end

    def java_script
      s = "$(function() {\n"

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

      s << "\n});\n"

      s
    end

    def line_graph(field, color = nil)
      s = "var #{field}_data = [\n"

      data_set = []
      start_time = @activity.fit_activity.sessions[0].start_time.to_i
      @activity.fit_activity.records.each do |r|
        value = r.send(field)
        if field == 'pace'
          if value > 20.0
            value = nil
          else
            value = (value * 3600.0 * 1000).to_i
          end
        end
        data_set << [ ((r.timestamp.to_i - start_time) * 1000).to_i, value ]
      end

      # We don't want to plot charts with all nil values.
      unless data_set.find { |v| v[1] != nil }
        @empty_charts[field] = true
        return ''
      end
      s << data_set.map do |set|
        "[ #{set[0]}, #{set[1] ? set[1] : 'null'} ]"
      end.join(', ')

      s << <<"EOT"
	  	];

	  	$.plot("##{field}_chart",
             [ { data: #{field}_data,
                 #{color ? "color: \"#{color}\"," : ''}
                 lines: { show: true#{field == 'pace' ? '' :
                                      ', fill: true'} } } ],
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
        next unless (value = r.send(field))
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

      # We don't want to plot charts with all nil values.
      if data_sets.values.flatten.empty?
        @empty_charts[field] = true
        return ''
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

    def chart_div(doc, field, title)
      # Don't plot frame for graph without data.
      return if @empty_charts[field]

      frame(doc, title) {
        doc.div({ 'id' => "#{field}_chart", 'class' => 'chart-placeholder'})
      }
    end

  end

end

