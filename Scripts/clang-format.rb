#!/usr/bin/env ruby


Dir.glob('Classes/**/*.[chm]') do |file|
  `clang-format -i #{file}`
  puts "failed to format file #{file}" if $? != 0
end
