#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ViewTop.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/HTMLBuilder'
require 'postrunner/NavButtonRow'

module PostRunner

  # This class generates the top part of the HTML page. It contains the logo
  # and the menu and navigation buttons.
  class ViewTop

    # Create a ViewTop object.
    # @param views [Array of NavButtonDef] icons and URLs for views
    # @param pages [Array of NavButtonDef] Full list of pages of this view.
    def initialize(views, pages)
      @views = views
      @pages = pages
    end

    # Generate the HTML code to that describes the top section.
    # @param doc [HTMLBuilder] Reference to the HTML document to add to.
    def to_html(doc)
      doc.unique(:viewtop_style) {
        doc.head { doc.style(style) }
      }
      doc.div({ :class => 'titlebar' }) {
        doc.div('PostRunner', { :class => 'title' })

        page_selector = NavButtonRow.new('right')
        @pages.each do |p|
          page_selector.addButton(p.icon, p.url)
        end
        page_selector.to_html(doc)

        view_selector = NavButtonRow.new
        @views.each do |v|
          view_selector.addButton(v.icon, v.url)
        end
        view_selector.to_html(doc)
      }
    end

    private

    def style
      <<EOT
.titlebar {
  width: 100%;
  height: 50px;
  margin: 0px;
	background: linear-gradient(#7FA1FF 0, #002EAC 50px);
}
.title {
  float: left;
  font-size: 24pt;
  font-style: italic;
  font-weight: bold;
  color: #F8F8F8;
  text-shadow: -1px -1px 0 #5C5C5C,
                1px -1px 0 #5C5C5C,
               -1px  1px 0 #5C5C5C,
                1px  1px 0 #5C5C5C;
  padding: 3px 30px;
}
EOT
    end

  end

end
