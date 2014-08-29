def create_fit_file(name, date, duration_minutes = 30)
  Fit4Ruby.write(name, create_fit_activity(date, duration_minutes))
end

def create_fit_activity(date, duration_minutes)
  ts = Time.parse(date)
  a = Fit4Ruby::Activity.new({ :timestamp => ts })
  a.total_timer_time = duration_minutes * 60
  a.new_user_profile({ :timestamp => ts,
                       :age => 33, :height => 1.78, :weight => 73.0,
                       :gender => 'male', :activity_class => 7.0,
                       :max_hr => 178 })

  a.new_event({ :timestamp => ts, :event => 'timer',
                :event_type => 'start_time' })
  a.new_device_info({ :timestamp => ts, :device_index => 0 })
  a.new_device_info({ :timestamp => ts, :device_index => 1,
                      :battery_status => 'ok' })
  0.upto((a.total_timer_time / 60) - 1) do |mins|
    a.new_record({
      :timestamp => ts,
      :position_lat => 51.5512 - mins * 0.0008,
      :position_long => 11.647 + mins * 0.002,
      :distance => 200.0 * mins,
      :altitude => 100 + mins * 3,
      :speed => 3.1,
      :vertical_oscillation => 90 + mins * 0.2,
      :stance_time => 235.0 * mins * 0.01,
      :stance_time_percent => 32.0,
      :heart_rate => 140 + mins,
      :cadence => 75,
      :activity_type => 'running',
      :fractional_cadence => (mins % 2) / 2.0
    })

    if mins > 0 && mins % 5 == 0
      a.new_lap({ :timestamp => ts })
    end
    ts += 60
  end
  a.new_session({ :timestamp => ts })
  a.new_event({ :timestamp => ts, :event => 'recovery_time',
                :event_type => 'marker',
                :data => 2160 })
  a.new_event({ :timestamp => ts, :event => 'vo2max',
                :event_type => 'marker', :data => 52 })
  a.new_event({ :timestamp => ts, :event => 'timer',
                :event_type => 'stop_all' })
  a.new_device_info({ :timestamp => ts, :device_index => 0 })
  ts += 1
  a.new_device_info({ :timestamp => ts, :device_index => 1,
                      :battery_status => 'low' })
  ts += 120
  a.new_event({ :timestamp => ts, :event => 'recovery_hr',
                :event_type => 'marker', :data => 132 })

  a.aggregate

  a
end


