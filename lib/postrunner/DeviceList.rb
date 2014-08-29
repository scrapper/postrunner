#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DeviceList.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/ViewWidgets'

module PostRunner

  class DeviceList

    include ViewWidgets

    def initialize(fit_activity)
      @fit_activity = fit_activity
    end

    def to_html(doc)
      frame(doc, 'Devices') {
        devices.each { |d| d.to_html(doc) }
      }
    end

    def to_s
      devices.map { |d| d.to_s }.join("\n")
    end

    private

    def devices
      tables = []
      seen_indexes = []
      @fit_activity.device_infos.reverse_each do |device|
        next if seen_indexes.include?(device.device_index) ||
                device.manufacturer.nil? ||
                device.manufacturer == 'Undocumented value 0' ||
                device.device_type == 'Undocumented value 0'

        tables << (t = FlexiTable.new)
        t.set_html_attrs(:style, 'margin-bottom: 15px') if tables.length != 1
        t.body

        t.cell('Manufacturer:', { :width => '40%' })
        t.cell(device.manufacturer, { :width => '60%' })
        t.new_row

        if (product = device.product)
          t.cell('Product:')
          rename = { 'fr620' => 'FR620', 'sdm4' => 'SDM4',
                     'hrm_run_single_byte_product_id' => 'HRM Run',
                     'hrm_run' => 'HRM Run' }
          product = rename[product] if rename.include?(product)
          t.cell(product)
          t.new_row
        end
        if (type = device.device_type)
          rename = { 'heart_rate' => 'Heart Rate Sensor',
                     'stride_speed_distance' => 'Footpod',
                     'running_dynamics' => 'Running Dynamics' }
          type = rename[type] if rename.include?(type)
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

        seen_indexes << device.device_index
      end

      tables.reverse
    end

  end

end

