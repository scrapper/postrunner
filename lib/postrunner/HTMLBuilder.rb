require 'nokogiri'

module PostRunner

  # Nokogiri is great, but I don't like the HTMLBuilder interface. This class
  # is a wrapper around Nokogiri that provides a more Ruby-like interface.
  class HTMLBuilder

    # Create a new HTMLBuilder object.
    def initialize
      # This is the Nokogiri Document that will store all the data.
      @doc = Nokogiri::HTML::Document.new
      # We only need to keep a stack of the currently edited nodes so we know
      # where we are in the node tree.
      @node_stack = []
    end

    # Any call to an undefined method will create a HTML node of the same
    # name.
    def method_missing(method_name, *args)
      node = Nokogiri::XML::Node.new(method_name.to_s, @doc)
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

    def add_child(parent, node)
      if parent
        parent.add_child(node)
      else
        @doc.add_child(node)
      end
    end

  end

end

