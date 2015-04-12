#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = HTMLBuilder.rb -- PostRunner - Manage the data from your Garmin sport devices.
#
# Copyright (c) 2014 by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'nokogiri'

module PostRunner

  # Nokogiri is great, but I don't like the HTMLBuilder interface. This class
  # is a wrapper around Nokogiri that provides a more Ruby-like interface.
  class HTMLBuilder

    # Create a new HTMLBuilder object.
    def initialize(title)
      # This is the Nokogiri Document that will store all the data.
      @doc = Nokogiri::HTML::Document.new
      # We only need to keep a stack of the currently edited nodes so we know
      # where we are in the node tree.
      @node_stack = []
      @tags = []

      @html = create_node('html') {
        @head = create_node('head') {
          create_node('meta', { 'http-equiv' => 'Content-Type',
                      'content' => 'text/html; charset=utf-8' })
          create_node('title', title)
        }
        @body = create_node('body')
      }
      @node_stack << @html
      @node_stack << @body
    end

    # Append nodes provided in block to head section of HTML document.
    def head
      @node_stack.push(@head)
      yield if block_given?
      unless @node_stack.pop == @head
        raise ArgumentError, "node_stack corrupted in head"
      end
    end

    # Append nodes provided in block to body section of HTML document.
    def body(*args)
      @node_stack.push(@body)
      args.each do |arg|
        if arg.is_a?(Hash)
          arg.each { |k, v| @body[k] = v }
        end
      end
      yield if block_given?
      unless @node_stack.pop == @body
        raise ArgumentError, "node_stack corrupted in body"
      end
    end

    # Only execute the passed block if the provided tag has not been added
    # yet.
    def unique(tag)
      unless @tags.include?(tag)
        @tags << tag
        yield if block_given?
      end
    end

    # Any call to an undefined method will create a HTML node of the same
    # name.
    def method_missing(method_name, *args, &block)
      create_node(method_name.to_s, *args, &block)
    end

    # Only needed to comply with style guides. This all calls to unknown
    # method will be handled properly. So, we always return true.
    def respond_to?(method)
      true
    end

    # Dump the HTML document as HTML formatted String.
    def to_html
      @doc.to_html
    end

    private

    def create_node(name, *args)
      node = Nokogiri::XML::Node.new(name, @doc)
      if (parent = @node_stack.last)
        parent.add_child(node)
      else
        @doc.add_child(node)
      end
      @node_stack.push(node)

      args.each do |arg|
        if arg.is_a?(String)
          node.add_child(Nokogiri::XML::Text.new(arg, @doc))
        elsif arg.is_a?(Hash)
          # Hash arguments are attribute sets for the node. We just pass them
          # directly to the node.
          arg.each { |k, v| node[k] = v }
        end
      end

      yield if block_given?
      @node_stack.pop
    end

    def add_child(parent, node)
      if parent
        parent.add_child(node)
      else
        @doc.add_child(node)
      end
    end

  end

end

