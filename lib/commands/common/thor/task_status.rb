module DTK::Client
  module TaskStatusMixin
      def task_status_aux(id,type,options)
        id_field = "#{type}_id".to_sym
        if options.wait?
          # there will be infinite loop until intereputed with CTRL+C
          begin
            response = nil
            loop do 
              post_body = {
                id_field => id,
                :format => :table
              }
              response = post rest_url("#{type}/task_status"), post_body
              response.render_table(:task_status)
              system('clear')
              response.render_data(true)

              # stop pulling when top level task succeds, fails or timeout
              if response and response.data and response.data.first
                #TODO: may fix in server, but now top can have non executing state but a concurrent branch can execute; so
                #chanding bloew for time being
                #break unless response.data.first["status"].eql? "executing"
                break unless response.data.find{|r|r["status"].eql? "executing"}
              end
            
              wait_animation("Watching #{type} task status [ #{DEBUG_SLEEP_TIME} seconds refresh ] ",DEBUG_SLEEP_TIME)
            end
          rescue Interrupt => e
            puts ""
            # this tells rest of the flow to skip rendering of this response
            response.skip_render = true unless response.nil?
          end
        else
          post_body = {
            id_field => id,
            :format => :table
          }
          response = post rest_url("#{type}/task_status"), post_body
          response.print_error_table = true
          response.render_table(:task_status)
        end
      end
    end

end
