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
      t.row([ 'Date:', session.start_time])
      t.row([ 'Distance:', "#{'%.2f' % (session.total_distance / 1000.0)} km" ])
      t.row([ 'Time:', secsToHMS(session.total_timer_time) ])
      t.row([ 'Avg. Pace:',
              "#{speedToPace(session.avg_speed)} min/km" ])
      t.row([ 'Total Ascend:', "#{session.total_ascend} m" ])
      t.row([ 'Total Descend:', "#{session.total_descent} m" ])
      t.row([ 'Calories:', "#{session.total_calories} kCal" ])
      t.row([ 'Avg. HR:', session.avg_heart_rate ?
              "#{session.avg_heart_rate} bpm" : '-' ])
      t.row([ 'Max. HR:', session.max_heart_rate ?
              "#{session.max_heart_rate} bpm" : '-' ])
      t.row([ 'Training Effect:', session.total_training_effect ?
              session.total_training_effect : '-' ])
      t.row([ 'Avg. Run Cadence:',
              session.avg_running_cadence ?
              "#{session.avg_running_cadence.round} spm" : '-' ])
      t.row([ 'Avg. Vertical Oscillation:',
              session.avg_vertical_oscillation ?
              "#{'%.1f' % (session.avg_vertical_oscillation / 10)} cm" : '-' ])
      t.row([ 'Avg. Ground Contact Time:',
              session.avg_stance_time ?
              "#{session.avg_stance_time.round} ms" : '-' ])
      t.row([ 'Avg. Stride Length:',
              session.avg_stride_length ?
              "#{'%.2f' % (session.avg_stride_length / 2)} m" : '-' ])

      t.to_s
    end

    def laps
      t = FlexiTable.new
      t.head
      t.row([ 'Duration', 'Distance', 'Avg. Pace', 'Stride', 'Cadence',
              'Avg. HR', 'Max. HR' ])
      t.set_column_attributes(Array.new(7, { :halign => :right }))
      t.body
      @activity.laps.each do |lap|
        t.cell(secsToHMS(lap.total_timer_time))
        t.cell('%.2f' % (lap.total_distance / 1000.0))
        t.cell(speedToPace(lap.avg_speed))
        t.cell(lap.total_strides ?
               '%.2f' % (lap.total_distance / (2 * lap.total_strides)) : '')
        t.cell(lap.avg_running_cadence && lap.avg_fractional_cadence ?
               '%.1f' % (2 * lap.avg_running_cadence +
                         (2 * lap.avg_fractional_cadence) / 100.0) : '')
        t.cell(lap.avg_heart_rate.to_s)
        t.cell(lap.max_heart_rate.to_s)
        t.new_row
      end
      t.to_s
    end

  end

end

