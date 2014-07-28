require 'fit4ruby'
require 'postrunner/FlexiTable'

module PostRunner

  class ActivityReport

    include Fit4Ruby::Converters

    def initialize(activity)
      @activity = activity
    end

    def to_s
      session = @activity.sessions[0]

      summary(session) + "\n" + laps
    end

    private

    def summary(session)
      t = FlexiTable.new
      t.enable_frame(false)
      t.body
      t.row([ 'Date:', session.start_time ])
      t.row([ 'Distance:', "#{'%.2f' % (session.distance / 1000.0)} km" ])
      t.row([ 'Time:', secsToHMS(session.duration) ])
      t.row([ 'Avg. Pace:',
              "#{speedToPace(session.avg_speed)} min/km" ])
      t.row([ 'Total Ascend:', "#{session.ascend} m" ])
      t.row([ 'Total Descend:', "#{session.descent} m" ])
      t.row([ 'Calories:', "#{session.calories} m" ])
      t.row([ 'Avg. HR:', "#{session.avg_heart_rate} bpm" ])
      t.row([ 'Max. HR:', "#{session.max_heart_rate} bpm" ])
      t.row([ 'Training Effect:', session.training_effect ])
      t.row([ 'Avg. Run Cadence:', "#{session.avg_running_cadence.round} spm" ])
      t.row([ 'Avg. Vertical Oscillation:',
              "#{'%.1f' % (session.avg_vertical_oscillation / 10)} cm" ])
      t.row([ 'Avg. Ground Contact Time:',
              "#{session.avg_stance_time.round} ms" ])
      t.row([ 'Avg. Stride Length:',
              "#{'%.2f' % (session.avg_stride_length / 2)} m" ])

      t.to_s
    end

    def laps
      t = FlexiTable.new
      t.head
      t.row([ 'Duration', 'Avg. Pace', 'Avg. HR', 'Max. HR' ])
      t.body
      @activity.laps.each do |lap|
        t.cell(secsToHMS(lap.total_timer_time))
        t.cell(speedToPace(lap.avg_speed))
        t.cell(lap.avg_heart_rate.to_s)
        t.cell(lap.max_heart_rate.to_s)
        t.new_row
      end
      t.to_s
    end

  end

end

