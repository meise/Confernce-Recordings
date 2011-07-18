# encoding: UTF-8
=begin
Copyright Daniel Meißner <dm@3st.be>, 2011

This file is part of a Encodaem script for video handling.

This script is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This Script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Encodaem.  If not, see <http://www.gnu.org/licenses/>.
=end

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

