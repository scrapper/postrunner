#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = UserProfileView.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'fit4ruby'

require 'postrunner/ViewFrame'

module PostRunner

  class UserProfileView

    def initialize(fit_activity, unit_system)
      @fit_activity = fit_activity
      @unit_system = unit_system
    end

    def to_html(doc)
      return nil if @fit_activity.user_profiles.empty?

      ViewFrame.new('User Profile', 600, profile).to_html(doc)
    end

    def to_s
      return '' if @fit_activity.user_profiles.empty?
      profile.to_s
    end

    private

    def profile
      t = FlexiTable.new
      profile = @fit_activity.user_profiles.first
      if profile.height
        unit = { :metric => 'm', :statute => 'ft' }[@unit_system]
        height = profile.get_as('height', unit)
        t.cell('Height:', { :width => '40%' })
        t.cell("#{'%.2f' % height} #{unit}", { :width => '60%' })
        t.new_row
      end
      if profile.weight
        unit = { :metric => 'kg', :statute => 'lbs' }[@unit_system]
        weight = profile.get_as('weight', unit)
        t.row([ 'Weight:', "#{'%.1f' % weight} #{unit}" ])
      end
      t.row([ 'Gender:', profile.gender ]) if profile.gender
      t.row([ 'Age:', "#{profile.age} years" ]) if profile.age
      t.row([ 'Max. Heart Rate:', "#{profile.max_hr} bpm" ]) if profile.max_hr
      if profile.activity_class
        t.row([ 'Activity Class:', profile.activity_class ])
      end
      if profile.metmax
        t.row([ 'METmax:', "#{profile.metmax} MET" ])
        t.row([ 'VO2max:', "#{'%.1f' % (profile.metmax * 3.5)} ml/kg/min" ])
      end
      t
    end

  end

end

