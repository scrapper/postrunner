#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ActivityLink.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014, 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'postrunner/HTMLBuilder'

module PostRunner

  # Generates the name of an Activity with a link to the ActivityReport.
  # Optionally, an icon can be shown for Activities that contain a current
  # personal record.
  class ActivityLink

    def initialize(activity, show_record_icon = false)
      @activity = activity
      @show_record_icon = show_record_icon
    end

    # Add the ActivityLink as HTML Elements to the document.
    # @param doc [HTMLBuilder] XML Document
    def to_html(doc)
      doc.unique(:activitylink_style) { doc.style(style) }

      doc.a(@activity.name, { :class => 'activity_link',
                              :href => @activity.fit_file[0..-5] + '.html' })
      if @show_record_icon && @activity.has_records?
        doc.img(nil, { :src => 'icons/record-small.png',
                       :style => 'vertical-align:middle' })
      end
    end

    # Convert the ActivityLink into a plain text form. Return the first 20
    # characters of the Activity name.
    def to_s
      @activity.name[0..19]
    end

    private

    def style
      <<EOT
.activity_link {
  padding: 0px 3px 0px 3px;
}
EOT
    end

  end

end

