require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","assembly")
include SpecThor


describe DTK::Client::Assembly do
  lists = ['none', 'nodes', 'components', 'tasks']
  $assembly_id = ''
  
  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Assembly)

  context "#list" do
    output = `dtk assembly list`

    it "should have assembly listing" do
      output.should match(/(assembly|id|empty)/)
    end

    unless output.nil?
      $assembly_id = output.match(/\D([0-9]+)\D/)
    end
  end

  context "#list/command" do
    unless $assembly_id.nil?
      lists.each do |l|
          case l
          when 'none'
             command = "dtk assembly #{$assembly_id} list none"
             output = `#{command}`

             it "should list all assemblies" do
               output.should match(/(assembly|id|empty)/)
             end
          when 'nodes'
             command = "dtk assembly #{$assembly_id} list #{l}"
             output = `#{command}`

             it "should list all #{l} for assembly with id #{$assembly_id}" do
               output.should match(/(node|id|empty)/)
             end
          when 'components'
            command = "dtk assembly #{$assembly_id} list #{l}"
             output = `#{command}`

             it "should list all #{l} for assembly with id #{$assembly_id}" do
               output.should match(/(component|id|empty)/)
             end
          when 'tasks'
            command = "dtk assembly #{$assembly_id} list #{l}"
             output = `#{command}`

             it "should list all #{l} for assembly with id #{$assembly_id}" do
               output.should match(/(task|id|empty)/)
             end
          end
      end
    end
  end

  # check help context menu
  context "#help" do
    # notice backticks are being used here this runs commands
    output = `dtk assembly help`

    # Process::Status for above command
    process_status = $?

    it "should have assembly converge listing" do
      output.should match(/(converge|empty)/)
    end

    it "should have assembly info listing" do
      output.should match(/(info|empty)/)
    end

    it "should have assembly remove-component listing" do
      output.should match(/(remove-component|empty)/)
    end

    it "should have assembly list listing" do
      output.should match(/(list|empty)/)
    end

  end

end
