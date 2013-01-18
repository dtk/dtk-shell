module DTK
  module Shell
    class ContextAux

      class << self

        def is_double_dot?(command)
          return command.match(/\.\.[\/]?/)
        end

        # returns number of first '..' elements in array
        def count_double_dots(entries)
          double_dots_count = 0
          # we check for '..' and remove them
          entries.each do |e| 
            if is_double_dot?(e)
              double_dots_count += 1  
            else
              break
            end
          end

          return double_dots_count
        end

      end
    end
  end
end