module PostRunner

  class FlexiTable

    class Attributes

      attr_accessor :min_terminal_width, :horizontal_alignment

      def initialize(attrs = {})
        @min_terminal_width = nil
        @horizontal_alignment = :left
      end

    end

    class Cell

      def initialize(table, content, attributes)
        @table = table
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
        column_attributes = @table.column_attributes[@column_index]
        alignment = column_attributes.horizontal_alignment
        width = column_attributes.min_terminal_width
        case alignment
        when :left
          s + ' ' * (width - s.length)
        when :right
          ' ' * (width - s.length) + s
        when :center
          w = width - s.length
          left_padding = w / 2
          right_padding = w / 2 + w % 2
          ' ' * left_padding + s + ' ' * right_padding
        end
      end

      def to_html
      end

    end

    class Row < Array

      def initialize(table)
        @table = table
        super()
      end

      def set_indicies(col_idx, row_idx)
        self[col_idx].set_indicies(col_idx, row_idx)
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
      c = Cell.new(self, content, attributes)
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
      @current_row << c

      c
    end

    def row(cells)
      cells.each { |c| cell(c) }
      new_row
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
      @body_rows[0].each.with_index do |c, i|
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
      @body_rows[0].each.with_index do |c, i|
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
      s = '+'
      @column_attributes.each do |c|
        s += '-' * c.min_terminal_width + '+'
      end
      s + "\n"
    end

  end

end

