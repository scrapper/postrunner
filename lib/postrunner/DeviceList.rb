#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DeviceList.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/ViewFrame'

module PostRunner

  class DeviceList

    include Fit4Ruby::Converters

    DeviceTypeNames = {
      'acceleration' => 'Accelerometer',
      'antfs' => 'Main Unit',
      'barometric_pressure' => 'Barometer',
      'bike_cadence' => 'Bike Cadence',
      'bike_power' => 'Bike Power Meter',
      'bike_speed' => 'Bike Speed',
      'bike_speed_cadence' => 'Bike Speed + Cadence',
      'environment_sensor_legacy' => 'GPS',
      'gps' => 'GPS',
      'heart_rate' => 'Heart Rate Sensor',
      'running_dynamics' => 'Running Dynamics',
      'stride_speed_distance' => 'Footpod'
    }
    ProductNames = {
      'hrm_run_single_byte_product_id' => 'HRM Run',
      'hrm_run' => 'HRM Run'
    }

    def initialize(fit_activity)
      @fit_activity = fit_activity
    end

    def to_html(doc)
      ViewFrame.new('Devices', 600, devices).to_html(doc)
    end

    def to_s
      devices.map { |d| d.to_s }.join("\n")
    end

    private

    def devices
      tables = []
      seen_indexes = []
      @fit_activity.device_infos.reverse_each do |device|
        next if seen_indexes.include?(device.device_index)

        tables << (t = FlexiTable.new)
        t.set_html_attrs(:style, 'margin-bottom: 15px') if tables.length != 1
        t.body

        t.cell('Index:', { :width => '40%' })
        t.cell(device.device_index.to_s, { :width => '60%' })
        t.new_row

        if (manufacturer = device.manufacturer)
          t.cell('Manufacturer:', { :width => '40%' })
          t.cell(manufacturer.upcase, { :width => '60%' })
          t.new_row
        end

        if (product = %w( garmin dynastream dynastream_oem ).include?(
            device.manufacturer) ? device.garmin_product : device.product) &&
           product != 0xFFFF
          # For unknown products the numerical ID will be returned.
          product = product.to_s unless product.is_a?(String)
          t.cell('Product:')
          # Beautify some product names. The others will just be upcased.
          product = ProductNames.include?(product) ?
            ProductNames[product] : product.upcase
          t.cell(product)
          t.new_row
        end

        if (type = device.device_type)
          # Beautify some device type names.
          type = DeviceTypeNames[type] if DeviceTypeNames.include?(type)
          t.cell('Device Type:')
          t.cell(type)
          t.new_row
        end

        if device.serial_number
          t.cell('Serial Number:')
          t.cell(device.serial_number)
          t.new_row
        end

        if device.software_version
          t.cell('Software Version:')
          t.cell(device.software_version)
          t.new_row
        end

        if (rx_ok = device.rx_packets_ok) && (rx_err = device.rx_packets_err)
          t.cell('Packet Errors:')
          t.cell('%d%%' % ((rx_err.to_f / (rx_ok + rx_err)) * 100).to_i)
          t.new_row
        end

        if device.battery_status
          t.cell('Battery Status:')
          t.cell(device.battery_status)
          t.new_row
        end

        if device.cum_operating_time
          t.cell('Cumulated Operating Time:')
          t.cell(secsToDHMS(device.cum_operating_time))
          t.new_row
        end

        seen_indexes << device.device_index
      end

      tables.reverse
    end

  end

end

