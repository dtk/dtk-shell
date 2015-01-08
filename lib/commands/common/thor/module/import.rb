# For Aldin
# TODO: keep import_git_module_aux and import_git_aux
# as backup for now, but looking for them to be moved to here and written in style where from_git() amd from_git_or_file()
# respectively replace import_git_module_aux and import_mdoule_aux
# key is that have simple public methods from_git() amd from_git_or_file() with a few high level steps that can largely use
# object attributes as way as passing info (i.e., use of @attrs)
# we can over time move methods over here and use inheritence and sub classes to share
module DTK::Client
  class CommonModule
    class Import < self
      def from_git()
        # put in a few high level methods that correspond to major steps being done, each of these setps will be private methods
        # this wil call from_git_or_file analogously to how mport_git_module_aux calls import_mdoule_aux although see if
        # there are some private methods that may be reused 
        # here is example how calls change
        # there may be some calls on command taht wil give errors 'private' so taht wil need to be changed 
        git_repo_url, module_name    = retrieve_arguments([:option_1!, :option_2!])
        namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)
        
        module_type  = @command.get_module_type(@context_params)
        thor_options = { :git_import => true}
        pp [:debug,git_repo_url, module_name,namespace, local_module_name,module_type]
        # ...
        
      end
      def from_git_or_file()
        # put in a few high level methods that correspond to major steps being done, ..
      end
      private
      # ... the methods that represent the basic steps of from_git and from_git_or_file
    end
  end
end
