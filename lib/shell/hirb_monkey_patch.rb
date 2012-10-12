require 'hirb'
module Hirb
	class Helpers::ObjectTable
	  def format_cell(value, cell_width)
	  	puts "GHOOOOOOOOOOOOOOOOOOOO"
	    text = String.size(value) > cell_width ?
	      (
	      (cell_width < 5) ? String.slice(value, 0, cell_width) : String.slice(value, 0, cell_width - 3) + '...'
	      ) : value
	    String.ljust(text, cell_width)
	  end
	end
end
