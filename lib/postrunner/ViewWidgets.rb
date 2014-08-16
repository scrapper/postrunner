#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ViewWidgets.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

module PostRunner

  module ViewWidgets

    def view_widgets_style(doc)
      doc.style(<<EOT
.widget_frame {
	box-sizing: border-box;
	width: 600px;
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
}
EOT
               )
    end

    def frame(doc, title)
      doc.div({ 'class' => 'widget_frame' }) {
        doc.div({ 'class' => 'widget_frame_title' }) {
          doc.b(title)
        }
        doc.div {
          yield if block_given?
        }
      }
    end

  end

end

