#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ChartView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/HRV_Analyzer'

module PostRunner

  class ChartView

    def initialize(activity, unit_system)
      @activity = activity
      @sport = activity.sport
      @unit_system = unit_system
      @empty_charts = {}
      @hrv_analyzer = HRV_Analyzer.new(@activity.fit_activity)
    end

    def to_html(doc)
      doc.unique(:chartview_style) {
        doc.head {
          [ 'jquery/jquery-2.1.1.min.js', 'flot/jquery.flot.js',
            'flot/jquery.flot.time.js' ].each do |js|
            doc.script({ 'language' => 'javascript',
                         'type' => 'text/javascript', 'src' => js })
          end
          doc.style(style)
        }
      }

      doc.script(java_script)
      if @sport == 'running' || @sport == 'multisport'
        chart_div(doc, 'pace', "Pace (#{select_unit('min/km')})")
      end
      if @sport != 'running'
        chart_div(doc, 'speed', "Speed (#{select_unit('km/h')})")
      end
      chart_div(doc, 'altitude', "Elevation (#{select_unit('m')})")
      chart_div(doc, 'heart_rate', 'Heart Rate (bpm)')
      if @hrv_analyzer.has_hrv_data?
        chart_div(doc, 'hrv', 'R-R Intervals/Heart Rate Variability (ms)')
        #chart_div(doc, 'hrv_score', 'HRV Score (30s Window)')
      end
      if @sport == 'running' || @sport == 'multisport'
        chart_div(doc, 'run_cadence', 'Run Cadence (spm)')
        chart_div(doc, 'vertical_oscillation',
                  "Vertical Oscillation (#{select_unit('cm')})")
        chart_div(doc, 'stance_time', 'Ground Contact Time (ms)')
      end
      chart_div(doc, 'temperature', 'Temperature (°C)')
    end

    private

    def select_unit(metric_unit)
      case @unit_system
      when :metric
        metric_unit
      when :statute
        { 'min/km' => 'min/mi', 'm' => 'ft', 'cm' => 'in', 'km/h' => 'mph',
          'bpm' => 'bpm', 'rpm' => 'rpm', 'spm' => 'spm',
          'ms' => 'ms' }[metric_unit]
      else
        Log.fatal "Unknown unit system #{@unit_system}"
      end
    end

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
	width: 580px;
	height: 200px;
	font-size: 14px;
	line-height: 1.2em;
}
EOT
    end

    def java_script
      s = "$(function() {\n"

      s << tooltip_div
      if @sport == 'running' || @sport == 'multisport'
        s << line_graph('pace', 'Pace', 'min/km', '#0A7BEE' )
      end
      if @sport != 'running'
        s << line_graph('speed', 'Speed', 'km/h', '#0A7BEE' )
      end
      s << line_graph('altitude', 'Elevation', 'm', '#5AAA44')
      s << line_graph('heart_rate', 'Heart Rate', 'bpm', '#900000')
      if @hrv_analyzer.has_hrv_data?
        s << line_graph('hrv', 's', '', '#900000')
        #s << line_graph('hrv_score', 'HRV Score', '', '#900000')
      end
      if @sport == 'running' || @sport == 'multisport'
        s << point_graph('run_cadence', 'Run Cadence', 'spm',
                         [ [ '#EE3F2D', 151 ],
                           [ '#F79666', 163 ],
                           [ '#A0D488', 174 ],
                           [ '#96D7DE', 185 ],
                           [ '#A88BBB', nil ] ])
        s << point_graph('vertical_oscillation', 'Vertical Oscillation', 'cm',
                         [ [ '#A88BBB', 67 ],
                           [ '#96D7DE', 84 ],
                           [ '#A0D488', 101 ],
                           [ '#F79666', 118 ],
                           [ '#EE3F2D', nil ] ])
        s << point_graph('stance_time', 'Ground Contact Time', 'ms',
                         [ [ '#A88BBB', 208 ],
                           [ '#96D7DE', 241 ],
                           [ '#A0D488', 273 ],
                           [ '#F79666', 305 ],
                           [ '#EE3F2D', nil ] ])
      end
      if @sport == 'cycling'
        s << line_graph('cadence', 'Cadence', 'rpm', '#A88BBB')
      end
      s << line_graph('temperature', 'Temperature', 'C', '#444444')

      s << "\n});\n"

      s
    end

    def tooltip_div
      <<"EOT"
        function timeToHMS(usecs) {
           var secs = parseInt(usecs / 1000.0);
           var s = secs % 60;
           var mins = parseInt(secs / 60);
           var m = mins % 60;
           var h = parseInt(mins / 60);
           s = (s < 10) ? "0" + s : s;
           if (h == 0) {
             return ("" + m + ":" + s);
           } else {
             m = (m < 10) ? "0" + m : m;
             return ("" + h + ":" + m + ":" + s);
           }
        };
        $("<div id='tooltip'></div>").css({
                position: "absolute",
                display: "none",
                border: "1px solid #888",
                padding: "2px",
                "background-color": "#EEE",
                opacity: 0.90,
                "font-size": "8pt"
        }).appendTo("body");
EOT
    end

    def line_graph(field, y_label, unit, color = nil)
      s = "var #{field}_data = [\n"

      data_set = []
      start_time = @activity.fit_activity.sessions[0].start_time.to_i
      min_value = nil
      if field == 'hrv_score'
        0.upto(@hrv_analyzer.total_duration.to_i - 30) do |t|
          next unless (hrv_score = @hrv_analyzer.lnrmssdx20(t, 30)) > 0.0
          min_value = hrv_score if min_value.nil? || min_value > hrv_score
          data_set << [ t * 1000, hrv_score ]
        end
      elsif field == 'hrv'
        1.upto(@hrv_analyzer.rr_intervals.length - 1) do |idx|
          curr_intvl = @hrv_analyzer.rr_intervals[idx]
          prev_intvl = @hrv_analyzer.rr_intervals[idx - 1]
          next unless curr_intvl && prev_intvl

          # Convert the R-R interval duration to ms.
          dt = (curr_intvl - prev_intvl) * 1000.0
          min_value = dt if min_value.nil? || min_value > dt
          data_set << [ @hrv_analyzer.timestamps[idx] * 1000, dt ]
        end
      else
        @activity.fit_activity.records.each do |r|
          value = r.get_as(field, select_unit(unit))

          next unless value

          if field == 'pace'
            # Slow speeds lead to very large pace values that make the graph
            # hard to read. We cap the pace at 20.0 min/km to keep it readable.
            if value > (@unit_system == :metric ? 20.0 : 36.0 )
              value = nil
            else
              value = (value * 3600.0 * 1000).to_i
            end
            min_value = 0.0
          else
            min_value = value if (min_value.nil? || min_value > value)
          end
          data_set << [ ((r.timestamp.to_i - start_time) * 1000).to_i, value ]
        end
      end

      # We don't want to plot charts with all nil values.
      unless data_set.find { |v| v[1] != nil }
        @empty_charts[field] = true
        return ''
      end
      s << data_set.map do |set|
        "[ #{set[0]}, #{set[1] ? set[1] : 'null'} ]"
      end.join(', ')
      s << "];\n"

      s << lap_marks(start_time)

      chart_id = "#{field}_chart"
      s << <<"EOT"
	  	var plot = $.plot(\"##{chart_id}\",
             [ { data: #{field}_data,
                 #{color ? "color: \"#{color}\"," : ''}
                 lines: { show: true#{field == 'pace' ? '' :
                                      ', fill: true'} } } ],
             { xaxis: { mode: "time" },
               grid: { markings: lap_marks, hoverable: true }
EOT
      if field == 'pace'
        s << ", yaxis: { mode: \"time\",\n" +
             "           transform: function (v) { return -v; },\n" +
             "           inverseTransform: function (v) { return -v; } }"
      else
        # Set the minimum slightly below the lowest found value.
        s << ", yaxis: { min: #{0.9 * min_value} }"
      end
      s << "});\n"
      s << lap_mark_labels(chart_id, start_time)
      s << hover_function(chart_id, y_label, select_unit(unit)) + "\n"
    end

    def point_graph(field, y_label, unit, colors)
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

        # Find the right set by looking at the maximum allowed values for each
        # color.
        colors.each.with_index do |col_max_value, i|
          col, range_max_value = col_max_value
          if range_max_value.nil? || value < range_max_value
            # A range_max_value of nil means all values allowed. The value is
            # in the allowed range for this set, so add the value as x/y pair
            # to the set.
            x_val = (r.timestamp.to_i - start_time) * 1000
            data_sets[i] << [ x_val, r.get_as(field, select_unit(unit)) ]
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

      s << lap_marks(start_time)

      chart_id = "#{field}_chart"
      s << "var plot = $.plot(\"##{chart_id}\", [\n"
      s << data_sets.map do |index, ds|
             "{ data: #{field}_data_#{index},\n" +
             "  color: \"#{colors[index][0]}\",\n" +
             "  points: { show: true, fillColor: \"#{colors[index][0]}\", " +
             "            fill: true, radius: 2 } }"
           end.join(', ')
      s << "], { xaxis: { mode: \"time\" },
                 grid: { markings: lap_marks, hoverable: true } });\n"
      s << lap_mark_labels(chart_id, start_time)
      s << hover_function(chart_id, y_label, select_unit(unit))

      s
    end

    def chart_div(doc, field, title)
      # Don't plot frame for graph without data.
      return if @empty_charts[field]

      ViewFrame.new(title) {
        doc.div({ 'id' => "#{field}_chart", 'class' => 'chart-placeholder'})
      }.to_html(doc)
    end

    def hover_function(chart_id, y_label, y_unit)
      <<"EOT"
        $("##{chart_id}").bind("plothover", function (event, pos, item) {
         if (item) {
           var x = timeToHMS(item.datapoint[0]);
           var y = #{y_label == 'Pace' ? 'timeToHMS(item.datapoint[1] / 60)' :
                                         'item.datapoint[1].toFixed(0)'};
           $("#tooltip").html("<b>#{y_label}:</b> " + y + " #{y_unit}<br/>" +
                              "<b>Time:</b> " + x + " h:m:s")
             .css({top: item.pageY-20, left: item.pageX+15})
             .fadeIn(200);
         } else {
           $("#tooltip").hide();
         }
       });
EOT
    end

    def lap_marks(start_time)
      # Use vertical lines to mark the end of each lap.
      s = "var lap_marks = [\n"
      s += @activity.fit_activity.laps.map do |lap|
        x = ((lap.timestamp.to_i - start_time) * 1000).to_i
        "\n  { color: \"#666\", lineWidth: 1, " +
        "xaxis: { from: #{x} , to: #{x} } }"
      end.join(",\n")
      s + "];\n"
    end

    def lap_mark_labels(chart_id, start_time)
      # Mark the vertical lap marks with the number of the lap right to the
      # left at the top end of the line.
      s = ''
      @activity.fit_activity.laps[0..-2].each do |lap|
        x = ((lap.timestamp.to_i - start_time) * 1000).to_i
        s += "$(\"##{chart_id}\").append(" +
             "\"<div style='position:absolute;" +
             "left:\" + (plot.pointOffset({x: #{x}, y: 0}).left - 18) + \"px;" +
             "top:7px;width:16px;" +
             "text-align:right;" +
             "color:#666;font-size:smaller'>" +
             "#{lap.message_index + 1}</div>\");\n"
      end
      s
    end

  end

end

