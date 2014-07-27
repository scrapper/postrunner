require 'fileutils'

require 'postrunner/Main'

describe PostRunner::Main do

  def postrunner(args)
    args = [ '--dbdir', @db_dir ] + args
    old_stdout = $stdout
    $stdout = (stdout = StringIO.new)
    PostRunner::Main.new(args)
    $stdout = old_stdout
    stdout.string
  end

  def create_fit_file(name, date)
    a = Fit4Ruby::Activity.new
    a.start_time = Time.parse(date)
    a.duration = 30 * 60
    Fit4Ruby.write(name, a)
  end

  before(:all) do
    @db_dir = File.join(File.dirname(__FILE__), '.postrunner')
    FileUtils.rm_rf(@db_dir)
    FileUtils.rm_rf('FILE1.FIT')
    create_fit_file('FILE1.FIT', '2014-07-01-8:00')
    #create_fit_file('FILE2.FIT', '2014-07-02-8:00')
  end

  after(:all) do
    FileUtils.rm_rf(@db_dir)
    FileUtils.rm_rf('FILE1.FIT')
  end

  it 'should abort without arguments' do
    lambda { postrunner([]) }.should raise_error SystemExit
  end

  it 'should abort with bad command' do
    lambda { postrunner(%w( foobar)) }.should raise_error SystemExit
  end

  it 'should support the -v option' do
    postrunner(%w( --version ))
  end

  it 'should check a FIT file' do
    postrunner(%w( check FILE1.FIT ))
  end

  it 'should list and empty archive' do
    postrunner(%w( list ))
  end

  it 'should import a FIT file' do
    postrunner(%w( import FILE1.FIT ))
  end

  it 'should check the imported file' do
    postrunner(%w( check :1 ))
  end

  it 'should list the imported file' do
    postrunner(%w( list )).index('FILE1.FIT').should be_a(Fixnum)
  end

end

