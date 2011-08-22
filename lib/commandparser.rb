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

require 'yaml'
require 'readline'
require 'abbrev'
require 'timeout'
require 'getoptlong'

class CommandParser
	include Readline
	attr_reader :currentgroup, :running, :allgroups, :options
	attr_writer :currentgroup, :running, :allgroups, :options


	def initialize
		@nogroup= Group.new()
		@nogroup.name = "No group"
		@currentgroup = @nogroup
		@allgroups = Hash.new()

		@commandlist = Hash.new()
		@helplist    = Hash.new()

		CommandParser.public_instance_methods(false).each do |meth|
			if meth =~ /^do_/
				meth.gsub!(/do_/,'')
				@commandlist[meth] = "do_" + meth
			end
			if meth=~ /^help_/
				meth.gsub!(/help_/,'')
				@helplist[meth] = "help_" + meth 
			end
		end

		# initialize abbrev and readline
		rebuild_readline_commands
	end

	# need to call this after:
	# changing groups, addcommand
	def rebuild_readline_commands
		@COMMANDS = @commandlist.keys + @currentgroup.commands.keys
		@ABBREV = @COMMANDS.abbrev
		Readline.completion_proc = proc do |string|
			@ABBREV[string]
		end
	end		

	def do_copyid(params)
		if params.length > 0
			s=SSHCopyIdFile.new(params[0],params[1])
			s.run
		else
			Output.puts "copyid user@host [rsa/dsa/identity]"
		end
	end	



	def do_clear(params)
		print `clear`
	end

	def help_clear
		Output.puts "Clears the screen"	
	end

	## TODO need to look for a leading / and use that path instead
	##		of storing the file inside of .shocto
	def do_save(params)
		filename = "shocto.default"
		if params.length > 0
			filename = params[0]
		end
		Output.puts "Saving to #{Globals.shoctohome}/#{filename}"
		begin
			data = YAML.dump(@allgroups)
			File.open(Globals.shoctohome + "/" + filename,"w") { |file| file.write(data) }
		rescue SystemCallError => boom
			Output.puts "Error saving: " + boom
		end
	end

	
	def do_load(params)
		filename = "shocto.default"
		if params.length > 0
			filename = params[0]
		end
		Output.puts "Loading #{filename}"
		begin
			file = File.open(Globals.shoctohome + "/" + filename,"r")
			data = file.read()
			@allgroups = YAML.load(data)
		rescue SystemCallError => boom
			if boom.class == Errno::ENOENT
				print "Can't file file #{Globals.shoctohome}/#{filename}, can I create it? [y/n] "
				answer = gets.chomp!
				if answer == "y"
					## create a new config file
					begin
						puts "Creating #{Globals.shoctohome}/#{filename}"
						do_save([filename])
					rescue SystemCallError => boomboom
						puts "Can't create file" + boomboom
					end
				end
			else
				Output.puts "Error opening file: " + boom
			end

		end
	end



	def do_help(params)
		if params.length > 0
			help=@helplist[params[0]]
			if help
				self.send(help)
			else
				Output.puts "No help available for #{params[0]}"
			end
		else
			@sorted = @commandlist.sort
			@sorted.each do | cmd,x|
				Output.puts cmd
			end
		end
	end



	def do_exit(params)
		@running = false
	end

	def do_listgroups(params)
		@allgroups.each {|x,y| Output.puts x}
	end

	def do_listservers(params)
		@currentgroup.servers.each {|x,y| Output.puts x}
	end

	def do_group(params)
		if params.length > 0
			if @allgroups[params[0]]
				@currentgroup = @allgroups[params[0]]
				rebuild_readline_commands
			end
		end
	end

	def do_addgroup(params)
		if params.length > 0
			temp = Group.new()
			temp.name = params[0]
			@currentgroup = temp
			if not @allgroups[params[0]]
				#
				Output.puts "Adding new group"
				@allgroups[params[0]] = temp
			end
		end
	end

	def do_addserver(params)
		if params.length > 0
			@currentgroup.servers[params[0]] = params[0]
		end
	end

	def do_rmserver(params)
		if params.length > 0
			@currentgroup.servers.delete(params[0])
			Output.puts "Removing #{params[0]}"
		end
	end

	def do_rmgroup(params)
		if params.length > 0
			if params[0] == @currentgroup.name
				@currentgroup = @nogroup
			end
			@allgroups.delete(params[0])
			Output.puts "Removing #{params[0]}"
		end
	end

	def do_rmcommand(params)
		if params.length > 0
			@currentgroup.commands.delete(params[0])
			Output.puts "Removing #{params[0]}"
		end
	end


	def do_optionset(params)
		if params.length == 1
			@options[params[0]] = "on"
		elsif params.length == 2
			@options[params[0]] = params[1]
		end
	end

	def do_optionunset(params)
		if params.length > 0
			@options.delete(params[0])	
		end
	end

	def do_optionlist(params)
		@options.each {|op,val| puts "#{op} = #{val}"}
	end

	def do_exec(params)
		if params.length > 0
			cmd = params.join(" ")
			#Output.puts '[' + cmd + ']'
			e=SSHCmdExec.new(@currentgroup.servers.values,cmd,@options)
			e.run()
		end # end if params
	end

	def do_execcon(params)
		if params.length > 0
			cmd = params.join(" ")
			e=SSHCmdExec.new(@currentgroup.servers.values,cmd)					   
			e.concurrent=true
			e.run()
		end # end if params
	end


	def do_lcd(params)
		if params.length >0
			Dir.chdir(params[0])
			Output.puts Dir.pwd
		end
	end




	def do_!(params)
		cmd = params.join(" ").to_s	
		Output.puts `#{cmd}`
	end


	def do_put(params)
		if params.length == 2
			localfile  = params[0]	
			remotefile = params[1]	
			# TODO check local file etc
			e=SCPCmdExec.new(@currentgroup.servers.values,"")
			e.localfile = localfile
			e.remotefile = remotefile
			e.run()
		else
			Output.puts "put localfile remotefile"	
		end
	end

	def do_addcommand(params)
		cmd = Command.new()
		print "Command name (ie chkuptime):"
		cmd.name = gets
		print "Command description:"
		cmd.desc = gets
		print "Command:"
		cmd.cmd = gets
		cmd.name.chomp!
		cmd.desc.chomp!
		cmd.cmd.chomp!
		@currentgroup.commands[cmd.name] = cmd
		rebuild_readline_commands
	end

	def do_listcommands(params)
		@currentgroup.commands.each do |name,cmd|
			Output.puts "#{cmd.name}"
			Output.puts "\t#{cmd.desc}"	
			Output.puts "\t#{cmd.cmd}"
			Output.puts ""
		end

	end




	def run(globaloptions)
		@currentgroup = Group.new()
		@currentgroup.name = "No group"
		@options = globaloptions

		@running = true
		while @running
			# reinstall this every time in case a command
			# installed its own (exec, execcon)
			Signal.trap("INT") do
				Output.puts("")
				Output.puts("Exiting Shocto")
				exit
			end

			if @options["scriptmode"] == true
				cmdstr = gets
				# exit on EOF
				if not cmdstr
					@running = false
					next
				end
			else
				cmdstr = readline("[#{@currentgroup.name}]>",true) 
			end

			if @options["scriptmode"] == true
				puts cmdstr
			end

			if cmdstr == ""
				next
			end
			Output.log(cmdstr)
			cmdlist = cmdstr.split()
			cmdroot = cmdlist[0]
			cmdparams = cmdlist[1,cmdlist.length-1]

			if cmdroot=~/&/
				puts "Concurrent!"
				cmdroot.sub!(/\&/,'con')
			end

			cmdmeth = @commandlist[cmdroot]
			if cmdmeth
				self.send(cmdmeth,cmdparams)
			else
				# else check the commands defined in currentgroup
				if @currentgroup.commands[cmdroot]
					groupcmd = @currentgroup.commands[cmdroot]
					params = Array.new()
					params << groupcmd.cmd
					do_exec(params)
				else
					Output.puts "Invalid command"
				end
			end
		end
	end
end


