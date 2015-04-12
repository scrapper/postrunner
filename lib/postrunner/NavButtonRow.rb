#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = NavButtonRow.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/HTMLBuilder'

module PostRunner

  # Auxilliary class that stores the name of an icon file and a URL as a
  # String. It is used to describe a NavButtonRow button.
  class NavButtonDef < Struct.new(:icon, :url)
  end

  # A NavButtonRow is a row of buttons used to navigate between HTML pages.
  class NavButtonRow

    # A class to store the icon and URL of a button in the NavButtonRow
    # objects.
    class Button

      # Create a Button object.
      # @param icon [String] File name of the icon file
      # @param url [String] URL of the page to change to
      def initialize(icon, url = nil)
        @icon = icon
        @url = url
      end

      # Add the object as HTML Elements to the document.
      # @param doc [HTMLBuilder] XML Document
      def to_html(doc)
        if @url
          doc.a({ :href => @url }) {
            doc.img({ :src => "icons/#{@icon}", :class => 'active_button' })
          }
        else
          doc.img({ :src => "icons/#{@icon}", :class => 'inactive_button' })
        end
      end

    end

    # Create a new NavButtonRow object.
    # @param float [String, Nil] specifies if the HTML representation should
    # be a floating object that floats left or right.
    def initialize(float = nil)
      unless float.nil? || %w( left right ).include?(float)
        raise ArgumentError "float argument must be nil, 'left' or 'right'"
      end

      @float = float
      @buttons = []
    end

    # Add a new button to the NavButtonRow object.
    # @param icon [String] File name of the icon file
    # @param url [String] URL of the page to change to
    def addButton(icon, url = nil)
      @buttons << Button.new(icon, url)
    end

    # Add the object as HTML Elements to the document.
    # @param doc [HTMLBuilder] XML Document
    def to_html(doc)
      doc.unique(:nav_button_row_style) {
        doc.head { doc.style(style) }
      }
      doc.div({ :class => 'nav_button_row',
                :style => "width: #{@buttons.length * (32 + 10)}px; " +
                          "#{@float ? "float: #{@float};" :
                             'margin-left: auto; margin-right: auto'}"}) {
        @buttons.each { |btn| btn.to_html(doc) }
      }
    end

    private

    def style
      <<"EOT"
.nav_button_row {
  padding: 3px 30px;
}
.active_button {
  padding: 5px;
}
.inactive_button {
  padding: 5px;
  opacity: 0.4;
}
EOT
    end

  end

end
