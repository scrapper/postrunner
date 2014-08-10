require 'fit4ruby'

require 'postrunner/HTMLBuilder'
require 'postrunner/ActivityReport'
require 'postrunner/ViewWidgets'
require 'postrunner/TrackView'
require 'postrunner/ChartView'

module PostRunner

  class ActivityView

    include ViewWidgets

    def initialize(activity, output_dir)
      @activity = activity
      @output_dir = output_dir
      @output_file = nil

      ensure_output_dir

      @doc = HTMLBuilder.new
      generate_html(@doc)
      write_file
      show_in_browser
    end

    private

    def ensure_output_dir
      unless Dir.exists?(@output_dir)
        begin
          Dir.mkdir(@output_dir)
        rescue SystemCallError
          Log.fatal "Cannot create output directory '#{@output_dir}': #{$!}"
        end
      end
    end

    def generate_html(doc)
      @report = ActivityReport.new(@activity.fit_activity)
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
        style(doc)
        view_widgets_style(doc)
        @chart_view.head(doc)
        @track_view.head(doc)
      }
    end

    def style(doc)
      doc.style(<<EOT
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
.widget_container {
	box-sizing: border-box;
	width: 600px;
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
EOT
               )
    end

    def body(doc)
      doc.body({ 'onload' => 'init()' }) {
        doc.div({ 'class' => 'main' }) {
          doc.div({ 'class' => 'left_col' }) {
            @report.to_html(doc)
            @track_view.div(doc)
          }
          doc.div({ 'class' => 'right_col' }) {
            @chart_view.div(doc)
          }
        }
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

    def show_in_browser
      system("firefox \"#{@output_file}\" &")
    end

  end

end

