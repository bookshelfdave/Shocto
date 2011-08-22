#!/usr/bin/ruby
###############################################################################
#  Shocto
#  Copyright (C) 2005 David Parfitt (dparfitt@users.sourceforge.net)
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
###############################################################################

# TODO options for each group, server, command
# TODO fix abs path for loading/saving config files

require 'yaml'
require 'readline'
require 'abbrev'
require 'timeout'
require 'getoptlong'


# lame class that defines system globals... hence the name 
class Globals
	@@shoctohome=nil
	def Globals.shoctohome
		@@shoctohome
	end

	def Globals.shoctohome=(path)
		@@shoctohome=path
	end
end



# this class captures output from the app and sends to a log file etc
class Output
	@@logfile = nil
	@@logfilename = nil
	def Output.logfile(file)
		@@logfilename = file
	end

	def Output.open
		if @@logfilename
			Output.puts "Opening log file #{@@logfilename}"
			begin
				@@logfile=File.new(@@logfilename,"w")	
			rescue => bang
				Output.puts "Error opening log file: " + bang
			end
		end
	end

	def Output.close
		if @@logfile
			begin
				puts "Closing log file"
				@@logfile.close
			rescue IOError => bang
				Output.puts "Error closing log file: " + bang
			end
		end
	end

	# just log to a file if its open
	def Output.log(line)
		if @@logfile
			@@logfile.puts "#{Time.new} #{line}"
		end
	end

	def Output.puts(line)
		STDOUT.puts "#{line}"
		if @@logfile
			@@logfile.puts "#{Time.new} #{line}"
		end
	end
end






class Command
	attr_reader :name, :cmd, :desc
	attr_writer :name, :cmd, :desc

	def initialize
	end
end

class Group
	attr_reader :name, :servers, :options, :commands
	attr_writer :name, :servers, :options, :commands

	def initialize
		@servers = Hash.new()
		@options = Hash.new()
		@commands = Hash.new()
		@options['concurrent'] = false
		@options['numconcurrent'] = 3
		@options['interleave']    = true
	end

end


def shoctoinit
	## check for ssh
	sshpath =`which ssh`.chomp!
	if not sshpath
		puts "Cannot find ssh"
		exit
	end

	if not File.executable?(sshpath)
		puts "Cannot find ssh executable"
		exit
	end

	home = ENV['HOME'] + '/.shocto'
	if not File.exists?(home)
		print '~/.shocto does not exist. Can I create it? [y/n] '		
		answer=gets.chomp!
		if answer=='y'
			begin
				Dir.mkdir(home)
				Globals.shoctohome=home
			rescue
				puts "Oops, can't create #{home}"
				Globals.shoctohome=Dir.pwd
			end
		else
			Globals.shoctohome=Dir.pwd
		end
	else
		Globals.shoctohome=home
	end

end


