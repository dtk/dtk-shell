module DTK
  module Client
    module CommonUtil
      class << self
        def substract_array_once(array1, array2, substract_from_back = false)
          # we substract from reverse if flag set
          array1 = array1.reverse if substract_from_back

          array2.each do |element|
            if index = array1.index(element)
              array1.delete_at(index)
            end
          end

          substract_from_back ? array1.reverse : array1
        end
      end
    end
  end
end