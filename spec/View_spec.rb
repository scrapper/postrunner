#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = View_spec.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2015 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'spec_helper'
require 'postrunner/View'
require 'postrunner/ViewButtons'
require 'postrunner/PagingButtons'

module PostRunner

  describe PostRunner::View do

    before(:all) do
      @view_names = %w( activities record )
      delete_files
    end

    after(:all) do
      delete_files
    end

    def delete_files
      @view_names.each do |vn|
        page_files(vn).each do |pf|
          File.delete(pf) if File.exist?(pf)
        end
      end
    end

    def page_files(vn)
      1.upto(vn == 'record' ? 5 : 3).map { |i| "#{vn}-page#{i}.html" }
    end

    it 'should generate view files with multiple pages' do
      views = ViewButtons.new(
        @view_names.map{ |vn| NavButtonDef.
                              new("#{vn}.png", "#{vn}-page1.html") }
      )
      @view_names.each do |vn|
        views.current_page = vn + '-page1.html'
        pages = PagingButtons.new(page_files(vn))
        page_files(vn).each do |file|
          pages.current_page = file
          PostRunner::View.new("Test File: #{file}", views, pages).body.
            write(file)
          expect(File.exist?(file)).to be true
        end
      end
    end

  end

end
