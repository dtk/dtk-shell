module DTK::Client
  class Execute
    # TODO: have a Base that is not just for commands (CommandBase)
    extend CommandBase

    def self.test()
      response = post rest_url('service_module/list'), {}
      pp response
    end
  end
end
