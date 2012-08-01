
=begin RENAME FILES
Dir['/home/haris/DTK/dtk-client/lib/commands/thor/*.rb'].each do |f|
  File.rename(f, f.to_s.gsub(/_command/,''))
end
=end


