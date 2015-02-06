require File.expand_path('../../lib/client', File.dirname(__FILE__))
require File.expand_path('../../lib/parser/adapters/thor',    File.dirname(__FILE__))
require File.expand_path('../../lib/shell/context', File.dirname(__FILE__))
require File.expand_path('../../lib/shell/domain/context_entity', File.dirname(__FILE__))
require File.expand_path('../../lib/shell/domain/active_context', File.dirname(__FILE__))
require File.expand_path('../../lib/shell/domain/context_params', File.dirname(__FILE__))
require File.expand_path('../../lib/shell/domain/override_tasks', File.dirname(__FILE__))
Dir[File.expand_path('../../lib/shell/parse_monkey_patch.rb', File.dirname(__FILE__))].each {|file| require file }

require 'shellwords'
require 'rspec'

module SpecThor

  include DTK::Client::Auxiliary

  def run_from_dtk_shell(line)
    args = Shellwords.split(line)
    cmd  = args.shift
    conn = DTK::Client::Session.get_connection()

    # special case for when no params are provided use help method
    if (cmd == 'help' || cmd.nil?)
        cmd  = 'dtk'
        args = ['help']
    end

    context = DTK::Shell::Context.new(true)

    entity_name, method_name, hashed_argv, options_args = context.get_dtk_command_parameters(cmd, args)
    entity_class = DTK::Client.const_get "#{cap_form(entity_name)}"

    return entity_class.execute_from_cli(conn,method_name,hashed_argv,options_args,true)
  end

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

    # this will stop buffering of print method, for proper output
    # STDOUT.sync = true

    clazz.all_tasks.each do |a,task|
      context "#{clazz.name} CLI command (#{task.name})" do

        # e.g. shell execute: dtk assembly list
        command = "dtk #{get_task_name(clazz.name)} #{task.name}"

        print ">> Surface test for #{command} ... "

        output = `#{command}`

        it "should not have errors." do
          output.should_not include("[INTERNAL ERROR]")
        end

        # test finished (print OK! in green color)
        puts "\e[32mOK!\e[0m"

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

  def unindent(num=nil)
    regex = num ? /^\s{#{num}}/ : /^\s*/
    gsub(regex, '').chomp
  end

  private

  ##
  # Method will take task name from class name
  # e.g. DTK::Client::Assembly => assembly
  def get_task_name(clazz_name)
    snake_form(clazz_name.split('::').last).downcase
  end


end