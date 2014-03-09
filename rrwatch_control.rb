#!/usr/bin/ruby

require 'rubygems' 
require 'daemons'


#http://daemons.rubyforge.org/classes/Daemons.html#M000004
options = {
    :multiple => false,
    :monitor => true,
    :dir_mode => :system,
}


Daemons.run('/usr/local/bin/rrwatch.rb', options)
