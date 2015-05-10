#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = EPO_Downloader.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'uri'
require 'net/http'

module PostRunner

  # This class can download the current set of Extended Prediction Orbit data
  # for GPS satellites and store them in the EPO.BIN file format. Some Garmin
  # devices pick up this file under GARMIN/GARMIN/REMOTESW/EPO.BIN.
  class EPO_Downloader

    @@URI = URI('http://omt.garmin.com/Rce/ProtobufApi/EphemerisService/GetEphemerisData')
    # This is the payload of the POST request. It was taken from
    # http://www.kluenter.de/garmin-ephemeris-files-and-linux/. It may contain
    # a product ID or serial number.
    @@POST_DATA = "\n-\n\aexpress\u0012\u0005de_DE\u001A\aWindows\"\u0012601 Service Pack 1\u0012\n\b\x8C\xB4\x93\xB8\u000E\u0012\u0000\u0018\u0000\u0018\u001C\"\u0000"
    @@HEADER = {
      'Garmin-Client-Name' => 'CoreService',
      'Content-Type' => 'application/octet-stream',
      'Content-Length' => '63'
    }

    # Create an EPO_Downloader object.
    def initialize
      @http = Net::HTTP.new(@@URI.host, @@URI.port)
      @request = Net::HTTP::Post.new(@@URI.path, initheader = @@HEADER)
      @request.body = @@POST_DATA
    end

    # Download the current EPO data from the Garmin server and write it into
    # the specified output file.
    # @param output_file [String] The name of the output file. Usually this is
    #        'EPO.BIN'.
    def download(output_file)
      return false unless (epo = get_epo_from_server)
      return false unless (epo = fix(epo))
      return false unless check_epo_data(epo)
      write_file(output_file, epo)
      Log.info "Extended Prediction Orbit (EPO) data has been downloaded " +
               "from Garmin site."

      true
    end

    private

    def get_epo_from_server
      res = @http.request(@request)
      if res.code.to_i != 200
        Log.error "Extended Orbit Prediction (EPO) data download failed: #{res}"
        return nil
      end
      res.body
    end

    # The downloaded data contains Extended Prediction Orbit data for 6 hour
    # windows for 7 days. Each EPO set is 2307 bytes long, but the first 3
    # bytes must be removed for the FR620 to understand it.
    # https://forums.garmin.com/showthread.php?79555-when-will-garmin-express-mac-be-able-to-sync-GPS-EPO-bin-file-on-fenix-2&p=277398#post277398
    # The 2304 bytes consist of 32 sets of 72 byte GPS satellite data.
    # http://www.vis-plus.ee/pdf/SIM28_SIM68R_SIM68V_EPO-II_Protocol_V1.00.pdf
    def fix(epo)
      unless epo.length == 28 * 2307
        Log.error "GPS data has unexpected length of #{epo.length} bytes"
        return nil
      end

      epo_fixed = ''
      0.upto(27) do |i|
        offset = i * 2307
        # The fill bytes always seem to be 0. Let's issue a warning in case
        # this ever changes.
        unless epo[offset].to_i == 0 &&
               epo[offset + 1].to_i == 0 &&
               epo[offset + 2].to_i == 0
          Log.warning "EPO fill bytes are not 0 bytes"
        end
        epo_fixed += epo[offset + 3, 2304]
      end

      epo_fixed
    end

    def check_epo_data(epo)
      # Convert EPO string into Array of bytes.
      epo = epo.bytes.to_a
      unless epo.length == 28 * 72 * 32
        Log.error "EPO file has wrong length (#{epo.length})"
        return false
      end
      date_1980_01_06 = Time.parse("1980-01-06T00:00:00+00:00")
      now = Time.now
      end_date = start_date = nil
      # Split the EPO data into Arrays of 32 * 72 bytes.
      epo.each_slice(32 * 72).to_a.each do |epo_set|
        # For each of the 32 satellites we have 72 bytes of data.
        epo_set.each_slice(72).to_a.each do |sat|
          # The last byte is an XOR checksum of the first 71 bytes.
          xor = 0
          0.upto(70) { |i| xor ^= sat[i] }
          unless xor == sat[71]
            Log.error "Checksum error in EPO file"
            return false
          end
          # The first 3 bytes of every satellite record look like a timestamp.
          # I assume they are hours after January 6th, 1980 UTC. They probably
          # indicate the start of the 6 hour window that the data is for.
          hours_after_1980_01_06 = sat[0] | (sat[1] << 8) | (sat[2] << 16)
          date = date_1980_01_06 + hours_after_1980_01_06 * 60 * 60
          if date > now + 8 * 24 * 60 * 60
            Log.warn "EPO timestamp (#{date}) is too far in the future"
          elsif date < now - 24 * 60 * 60
            Log.warn "EPO timestamp (#{date}) is too old"
          end
          start_date = date if start_date.nil? || date < start_date
          end_date = date if end_date.nil? || date > end_date
        end
      end
      Log.info "EPO data is valid from #{start_date} to " +
               "#{end_date + 6 * 60 * 60}."

      true
    end

    def write_file(output_file, data)
      begin
        File.write(output_file, data)
      rescue IOError
        Log.fatal "Cannot write EPO file '#{output_file}': #{$!}"
      end
    end

  end

end

