#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ViewBottom.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/HTMLBuilder'
require 'postrunner/version'

module PostRunner

  # This class generates the footer of a HTML page.
  class ViewBottom

    # Generate the HTML code to that describes the foot section.
    # @param doc [HTMLBuilder] Reference to the HTML document to add to.
    def to_html(doc)
      doc.unique(:viewbottom_style) {
        doc.head { doc.style(style) }
      }
      doc.div({ :class => 'footer' }){
        doc.hr
        doc.div({ :class => 'copyright' }) {
          doc.text("Generated by ")
          doc.a('PostRunner',
                { :href => 'https://github.com/scrapper/postrunner' })
          doc.text(" #{VERSION} on #{Time.now}")
        }
      }
    end

    private

    def style
      <<EOT
.footer {
  clear: both;
  width: 100%;
  height: 30px;
  padding: 15px 0px;
  text-align: center;
  font-size: 9pt;
}
EOT
    end
  end

end