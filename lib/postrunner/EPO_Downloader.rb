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

  # This class can download the current set of ephemeris data for GPS
  # satellites and store them in the EPO.BIN file format. Some Garmin devices
  # pick up this file under GARMIN/GARMIN/REMOTESW/EPO.BIN.
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

    # Download the current ephemeris data from the Garmin server and write it
    # into the specified output file.
    # @param output_file [String] The name of the output file. Usually this is
    #        'EPO.BIN'.
    def download(output_file)
      return false unless (epo = get_epo_from_server)
      return false unless (epo = fix(epo))
      write_file(output_file, epo)
      Log.info "GPS caching data has been downloaded from Garmin site."

      true
    end

    private

    def get_epo_from_server
      res = @http.request(@request)
      if res.code.to_i != 200
        Log.error "GPS data download failed: #{res}"
        return nil
      end
      res.body
    end

    # The downloaded data contains ephemeris data for 6 hour windows for 7
    # days. Each window set is 2307 bytes long, but the first 3 bytes must
    # be removed for the FR620 to understand it.
    # https://forums.garmin.com/showthread.php?79555-when-will-garmin-express-mac-be-able-to-sync-GPS-EPO-bin-file-on-fenix-2&p=277398#post277398
    def fix(epo)
      unless epo.length == 28 * 2307
        Log.error "GPS data has unexpected length of #{epo.length} bytes"
        return nil
      end

      epo_fixed = ''
      0.upto(27) do |i|
        offset = i * 2307
        epo_fixed += epo[offset + 3, 2304]
      end

      epo_fixed
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

