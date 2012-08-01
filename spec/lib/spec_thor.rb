require 'rspec'

module SpecThor

  ##
  # Capturing stream and returning string
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  ##
  # Method work with classes that inherit Thor class. Method will take each task
  # and just run it to check for any errors. In this case internal error.
  def test_task_interface(clazz)

    clazz.all_tasks.each do |a,task|
      context "#{clazz.name} CLI command (#{task.name})" do

        # e.g. executue dtk assembly list
        command = "dtk #{get_task_name(clazz.name)} #{task.name}"

        print ">> Surface test for #{command} ..."

        output = `#{command}`

        it "should not have errors." do
          output.should_not include("[INTERNAL ERROR]")
        end

        # test finished
        puts " OK"

      end
    end
  end


  # Redirects stderr and stdout to /dev/null.
  def silence_output
    $stderr = File.new('/dev/null', 'w')
    $stdout = File.new('/dev/null', 'w')
  end

  # Replace stdout and stderr so anything else is output correctly.
  def enable_output
    $stderr = STDOUT
    $stdout = STDERR
  end

  private 

  ##
  # Method will take task name from class name
  # e.g. Dtk::Client::Assembly => assembly
  def get_task_name(clazz_name)
    clazz_name.split('::').last.downcase
  end


end