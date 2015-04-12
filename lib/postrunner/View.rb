#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = View.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/HTMLBuilder'
require 'postrunner/ViewTop'
require 'postrunner/ViewBottom'

module PostRunner

  # Base class for all generated HTML pages.
  class View

    attr_reader :doc

    # Create a new View object.
    # @param title [String] The title of the HTML page
    # @param views [ViewButtons] List of all cross referenced View objects
    # @param pages [PagingButtons] List of all pages of this View
    def initialize(title, views, pages)
      @doc = HTMLBuilder.new(title)
      @views = views
      @pages = pages

      @doc.unique(:view_style) {
        style
      }
    end

    # Create the body section of the HTML document.
    def body
      ViewTop.new(@views, @pages).to_html(@doc)
      yield if block_given?
      ViewBottom.new.to_html(@doc)

      self
    end

    # Convert the View into an HTML document.
    def to_html
      @doc.to_html
    end

    # Write the HTML document to a file
    # @param file_name [String] Name of the file to write
    def write(file_name)
      begin
        File.write(file_name, to_html)
      rescue IOError
        Log.fatal "Cannot write file '#{file_name}: #{$!}"
      end
    end

    private

    def style
      @doc.head {
        @doc.style(<<"EOT"
body {
  font-family: verdana,arial,sans-serif;
  margin: 0px;
}
.flexitable {
  width: 100%;
  border: 2px solid #545454;
  border-collapse: collapse;
  font-size:11pt;
}
.ft_head_row {
  background-color: #DEDEDE
}
.ft_even_row {
  background-color: #FCFCFC
}
.ft_odd_row {
  background-color: #F1F1F1
}
.ft_cell {
  border: 1px solid #CCCCCC;
  padding: 1px 3px;
}
EOT
               )
      }
    end

  end

end
