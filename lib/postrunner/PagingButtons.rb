#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = PagingButtons.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/NavButtonRow'

module PostRunner

  # A class to generate a set of forward/backward buttons for an HTML page. It
  # can also include jump to first/last buttons.
  class PagingButtons

    # Create a new PagingButtons object.
    # @param page_urls [Array of String] Sorted list of all possible pages
    # @param end_buttons [Boolean] If true jump to first/last buttons are
    #        included
    def initialize(page_urls, end_buttons = true)
      if page_urls.empty?
        raise ArgumentError.new("'page_urls' must not be empty")
      end
      @pages = page_urls
      @current_page_index = 0
      @end_buttons = end_buttons
    end

    # Return the URL of the current page
    def current_page
      @pages[@current_page_index]
    end

    # Set the URL for the current page. It must be included in the URL set
    # passed at creation time. The forward/backward links will be derived from
    # the setting of the current page.
    # @param page_url [String] URL of the page
    def current_page=(page_url)
      unless (@current_page_index = @pages.index(page_url))
        raise ArgumentError.new("URL #{page_url} is not a known page URL")
      end
    end

    # Iterate over all buttons. A NavButtonDef object is passed to the block
    # that contains the icon and URL for the button. If no URL is set, the
    # button is inactive.
    def each
      %w( first back forward last ).each do |button_name|
        button = NavButtonDef.new
        button.icon = button_name + '.png'
        button.url =
          case button_name
          when 'first'
            @current_page_index == 0 || !@end_buttons ? nil : @pages.first
          when 'back'
            @current_page_index == 0 ? nil :
              @pages[@current_page_index - 1]
          when 'forward'
            @current_page_index == @pages.length - 1 ? nil :
              @pages[@current_page_index + 1]
          when 'last'
            @current_page_index == @pages.length - 1 ||
              !@end_buttons ? nil : @pages.last
          end

        yield(button)
      end
    end

  end

end
