
module DTK::Client
  module RemotesMixin

    def remote_active_aux(context_params)
      module_id, remote_name = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID,:option_1!], method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_name => remote_name
      }

      response = post rest_url("#{module_type}/make_git_remote_active"), post_body
      response
    end

    def remote_remove_aux(context_params)
      module_id, remote_name = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID,:option_1!], method_argument_names)
      module_type = get_module_type(context_params)

      unless options.force
        return unless Console.confirmation_prompt("Are you sure you want to remove '#{remote_name}'?")
      end

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_name => remote_name
      }

      response = post rest_url("#{module_type}/remove_git_remote"), post_body
      return response unless response.ok?
      OsUtil.print("Successfully removed remote '#{remote_name}'", :green)
      nil
    end

    def remote_add_aux(context_params)
      module_id, remote_name, remote_url = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID,:option_1!,:option_2!], method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_name => remote_name,
        :remote_url  => remote_url
      }

      response = post rest_url("#{module_type}/add_git_remote"), post_body
      return response unless response.ok?
      OsUtil.print("Successfully added remote '#{remote_name}'", :green)
      nil
    end

    def remote_list_aux(context_params)
      module_id   = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID], method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id
      }

      response = post rest_url("#{module_type}/info_git_remote"), post_body
      response.render_table(:remotes)
    end


  end
end