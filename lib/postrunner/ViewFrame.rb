#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ViewFrame.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  # Creates an HTML frame around the passed object or HTML block.
  class ViewFrame

    # Create a ViewFrame object.
    # @param title [String] Title/heading of the framed box
    # @param width [Fixnum or nil] Width of the frame. Use nil to set no
    #        width.
    # @param content [Any object that respons to to_html] Object to frame
    # @param &block [HTMLBuilder actions]
    def initialize(title, width = 600, content = nil, &block)
      @title = title
      @content = content
      @block = block
      @width = width
    end

    # Generate the HTML code for the frame and the enclosing content.
    # @param doc [HTMLBuilder] HTML document
    def to_html(doc)
      doc.unique(:viewframe_style) {
        # Add the necessary style sheet snippets to the document head.
        doc.head { doc.style(style) }
      }

      attr = { 'class' => 'widget_frame' }
      attr['style'] = "width: #{@width}px" if @width
      doc.div(attr) {
        doc.div({ 'class' => 'widget_frame_title' }) {
          doc.b(@title)
        }
        doc.div {
          # The @content holds an object that must respond to to_html to
          # generate the HTML code.
          if @content
            if @content.is_a?(Array)
              @content.each { |c| c.to_html(doc) }
            else
              @content.to_html(doc)
            end
          end
          # The block generates HTML code directly
          @block.yield if @block
        }
      }
    end

    private

    def style
      <<EOT
.widget_frame {
	box-sizing: border-box;
	padding: 10px 15px 15px 15px;
	margin: 15px auto 15px auto;
	border: 1px solid #ddd;
	background: #fff;
	background: linear-gradient(#f6f6f6 0, #fff 50px);
	background: -o-linear-gradient(#f6f6f6 0, #fff 50px);
	background: -ms-linear-gradient(#f6f6f6 0, #fff 50px);
	background: -moz-linear-gradient(#f6f6f6 0, #fff 50px);
	background: -webkit-linear-gradient(#f6f6f6 0, #fff 50px);
	box-shadow: 0 3px 10px rgba(0,0,0,0.15);
	-o-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
	-ms-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
	-moz-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
	-webkit-box-shadow: 0 3px 10px rgba(0,0,0,0.1);
}
.widget_frame_title {
  font-size:13pt;
  padding-bottom: 5px;
  text-align: left;
}
EOT
    end

  end

end

