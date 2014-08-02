require 'postrunner/FlexiTable'

describe PostRunner::FlexiTable do

  it 'should create a simple ASCII table' do
    t = PostRunner::FlexiTable.new do
      row(%w( a bb ))
      row(%w( ccc ddddd ))
    end
    puts t.to_s
  end

end

