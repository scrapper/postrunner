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
    # @param id [String] ID that is unique with regards to the rendered HTML
    #        page.
    # @param title [String] Title/heading of the framed box
    # @param width [Fixnum or nil] Width of the frame. Use nil to set no
    #        width.
    # @param content [Any object that respons to to_html] Object to frame
    # @param &block [HTMLBuilder actions]
    def initialize(id, title, width = 600, content = nil, hide_button = false,
                   &block)
      @id = id
      @title = title
      @content = content
      @block = block
      @width = width
      @hide_button = hide_button
    end

    # Generate the HTML code for the frame and the enclosing content.
    # @param doc [HTMLBuilder] HTML document
    def to_html(doc)
      doc.unique(:viewframe_style) {
        # Add the necessary style sheet snippets to the document head.
        doc.head {
          doc.style(style)
          doc.script({ 'language' => 'javascript', 'type' => 'text/javascript',
                       'src' => 'postrunner/postrunner.js' })
        }
      }
      doc.head {
        doc.script(<<"EOT"
function init_viewframe_#{@id}() {
  if (readCookie('postrunner_checkbox_#view_#{@id}') == 'false') {
    $('#checkbox-#{@id}').attr('checked', false);
    $('#view_#{@id}').hide();
  } else {
    $('#checkbox-#{@id}').attr('checked', true);
    $('#view_#{@id}').show();
  };
};
EOT
                  )
        doc.body_init_script("init_viewframe_#{@id}();")
      }

      attr = { 'class' => 'widget_frame' }
      attr['style'] = "width: #{@width}px" if @width
      doc.div(attr) {
        doc.div({ 'class' => 'widget_frame_title' }) {
          doc.div('style' => 'float:left') { doc.b(@title) }
          if @hide_button
            doc.div('style' => 'float:right') {
              doc.input('id' => "checkbox-#{@id}", 'type' => "checkbox",
                        'onclick' =>
                        "pr_view_frame_toggle(this, \"#view_#{@id}\");")
            }
          end
        }
        doc.div('class' => 'view_frame', 'id' => "view_#{@id}") {
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
  height: 23px;
}
.view_frame {
  padding-top: 5px;
}
EOT
    end

  end

end

