require 'rubygems'
require 'daemons'

# set Daemons options for additional information take a look into:
# http://daemons.rubyforge.org/classes/Daemons.html#M000004
options = {
  :app_name   => "encodaem",
  :log_output => true,
  :backtrace => true
}
Daemons.run(File.join(File.dirname(__FILE__), 'encodaem_code.rb'), options)

