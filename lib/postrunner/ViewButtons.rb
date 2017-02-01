#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ViewButtons.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # This class generates a simple icon menue to select from a set of HTML
  # pages (called views). The current page is represented as an inactive icon.
  # All other icons are buttons that contain links to other pages.
  class ViewButtons

    # Create a ViewButtons object.
    # @param views [Array of NavButtonDef] icons and URLs for all pages.
    def initialize(views)
      if views.empty?
        raise ArgumentError.new("'views' must not be empty")
      end
      @views = views
      self.current_page = views[0].url
    end

    # Get the URL of the current page
    # @return [String]
    def current_page
      @current_view_url
    end

    # Set the the current page.
    # @param page_url [String] URL of the current page. This must either be
    # nil or a URL in the predefined set.
    def current_page=(page_url)
      unless page_url
        @current_view_url = nil
        return
      end

      if (current = @views.find { |v| v.url == page_url })
        @current_view_url = current.url
      else
        raise ArgumentError.new("#{page_url} is not a URL of a known view")
      end
    end

    # Iterate over all buttons. A NavButtonDef object is passed to the block
    # that contains the icon and URL for the button. If no URL is set, the
    # button is inactive.
    def each
      @views.each do |view|
        view = view.clone
        if @current_view_url == view.url
          view.url = nil
        end
        yield(view)
      end

    end

  end

end
