module PostRunner

  class FlexiTable

    class Attributes

      attr_accessor :min_terminal_width, :halign

      def initialize(attrs = {})
        @min_terminal_width = nil
        @halign = nil

        attrs.each do |name, value|
          ivar_name = '@' + name.to_s
          unless instance_variable_defined?(ivar_name)
            Log.fatal "Unsupported attribute #{name}"
          end
          instance_variable_set(ivar_name, value)
        end
      end

      def [](name)
        ivar_name = '@' + name.to_s
        return nil unless instance_variable_defined?(ivar_name)

        instance_variable_get(ivar_name)
      end

    end

    class Cell

      def initialize(table, row, content, attributes)
        @table = table
        @row = row
        @content = content
        @attributes = attributes

        @column_index = nil
        @row_index = nil
      end

      def min_terminal_width
        @content.to_s.length
      end

      def set_indicies(col_idx, row_idx)
        @column_index = col_idx
        @row_index = row_idx
      end

      def to_s
        s = @content.to_s
        width = get_attribute(:min_terminal_width)
        case get_attribute(:halign)
        when :left, nil
          s + ' ' * (width - s.length)
        when :right
          ' ' * (width - s.length) + s
        when :center
          w = width - s.length
          left_padding = w / 2
          right_padding = w / 2 + w % 2
          ' ' * left_padding + s + ' ' * right_padding
        else
          raise "Unknown alignment"
        end
      end

      def to_html
      end

      private

      def get_attribute(name)
        @attributes[name] || @row.attributes[name] ||
          @table.column_attributes[@column_index][name]
      end

    end

    class Row < Array

      attr_reader :attributes

      def initialize(table)
        @table = table
        @attributes = nil
        super()
      end

      def cell(content, attributes)
        c = Cell.new(@table, self, content, attributes)
        self << c
        c
      end

      def set_indicies(col_idx, row_idx)
        self[col_idx].set_indicies(col_idx, row_idx)
      end

      def set_row_attributes(attributes)
        @attributes = Attributes.new(attributes)
      end

      def to_s
        s = ''
        frame = @table.frame

        s << '|' if frame
        s << join(@table.frame ? '|' : ' ')
        s << '|' if frame

        s
      end

    end

    attr_reader :frame, :column_attributes

    def initialize(&block)
      @head_rows = []
      @body_rows = []
      @foot_rows = []
      @column_count = 0

      @current_section = :body
      @current_row = nil

      @frame = true

      @column_attributes = []

      instance_eval(&block) if block_given?
    end

    def head
      @current_section = :head
    end

    def body
      @current_section = :body
    end

    def foot
      @current_section = :foot
    end

    def new_row
      @current_row = nil
    end

    def cell(content, attributes = {})
      if @current_row.nil?
        case @current_section
        when :head
          @head_rows
        when :body
          @body_rows
        when :foot
          @foot_rows
        else
          raise "Unknown section #{@current_section}"
        end << (@current_row = Row.new(self))
      end
      @current_row.cell(content, attributes)
    end

    def row(cells, attributes = {})
      cells.each { |c| cell(c) }
      set_row_attributes(attributes)
      new_row
    end

    def set_column_attributes(col_attributes)
      col_attributes.each.with_index do |ca, idx|
        @column_attributes[idx] = Attributes.new(ca)
      end
    end

    def set_row_attributes(row_attributes)
      unless @current_row
        raise "No current row. Use after first cell definition but before " +
              "new_row call."
      end
      @current_row.set_row_attributes(row_attributes)
    end

    def enable_frame(enabled)
      @frame = enabled
    end

    def to_s
      index_table
      calc_terminal_columns

      s = frame_line_to_s
      s << rows_to_s(@head_rows)
      s << frame_line_to_s unless @head_rows.empty?
      s << rows_to_s(@body_rows)
      s << frame_line_to_s unless @body_rows.empty?
      s << rows_to_s(@foot_rows)
      s << frame_line_to_s unless @foot_rows.empty?

      s
    end

    def to_html
    end

    private

    def index_table
      @column_count = (@head_rows[0] || @body_rows[0]).length

      @column_count.times do |i|
        index_table_rows(i, @head_rows)
        index_table_rows(i, @body_rows)
        index_table_rows(i, @foot_rows)
      end
    end

    def index_table_rows(col_idx, rows)
      rows.each.with_index do |r, row_idx|
        r.set_indicies(col_idx, row_idx)
      end
    end

    def calc_terminal_columns
      @column_count.times do |i|
        col_mtw = nil

        col_mtw = calc_section_teminal_columns(i, col_mtw, @head_rows)
        col_mtw = calc_section_teminal_columns(i, col_mtw, @body_rows)
        col_mtw = calc_section_teminal_columns(i, col_mtw, @foot_rows)

        @column_attributes[i] = Attributes.new unless @column_attributes[i]
        @column_attributes[i].min_terminal_width = col_mtw
      end
    end

    def calc_section_teminal_columns(col_idx, col_mtw, rows)
      rows.each do |r|
        if r[col_idx].nil?
          raise ArgumentError, "Not all rows have same number of cells"
        end

        mtw = r[col_idx].min_terminal_width
        if col_mtw.nil? || col_mtw < mtw
          col_mtw = mtw
        end
      end

      col_mtw
    end

    def rows_to_s(x_rows)
      x_rows.empty? ? '' : (x_rows.map { |r| r.to_s}.join("\n") + "\n")
    end

    def frame_line_to_s
      return '' unless @enable_frame
      s = '+'
      @column_attributes.each do |c|
        s += '-' * c.min_terminal_width + '+'
      end
      s + "\n"
    end

  end

end

