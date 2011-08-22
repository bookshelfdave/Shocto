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

# just for fun, i know there are better ways to do this
# copies a public key up to a server

class SSHCopyIdFile
	attr_reader :host, :keytype
	attr_writer :host, :keytype

	def initialize(host,keytype)
		@host = host
		@keytype = keytype
	end

	def run
		dotssh= ENV['HOME'] + "/.ssh"

		if not File.exists?(dotssh)
			Output.puts "Cannot find the .ssh directory. "
			Output.puts "Please consult the ssh and ssh-keygen man pages"
			return
		end

		if not @keytype
			ids=Dir.glob(dotssh + "/*.pub")
			if ids.length == 0
				Output.puts "Cannot find any public ssh id files."
				Output.puts "Please consult the ssh and ssh-keygen man page"
				return
			end

			if ids.length > 1
				Output.puts "You have more than one key. Please specify rsa, dsa, or etc"
				return
			else
				sshid=ids[0]
			end
		else
			@keytype.chomp!
			Output.puts "You specified #{@keytype}"
			if @keytype == "identity"
				sshid = dotssh + "/identity.pub"
			else
				sshid = dotssh + "/id_#{@keytype}.pub"	
			end
		end
		Output.puts "Using #{sshid}"

		# good enough for now - i know there is SSH_AUTH_SOCK
		# and other types of keys... good for now!
		cmd = 'cat ' + sshid + ' | ssh ' + host \
		+ ' "test -d .ssh || mkdir .ssh ; cat >> .ssh/authorized_keys ; chmod g-w . .ssh .ssh/authorized_keys"'
		anio = IO.popen(cmd,"r")
		while line = anio.gets
			Output.puts line
		end
	end
end




# this needs an overhaul 
class CmdExecBase
	attr_reader :hastimeout, :concurrent, :timeoutseconds, :servers, :command
	attr_writer :hastimeout, :concurrent, :timeoutseconds, :servers, :command

	attr_reader :commcmd, :options
	attr_writer :commcmd, :options

	def getcmd(server,cmdstring)
		return cmd = "echo [#{server}]-> " + cmdstring
	end

	def initialize(servers, command, globaloptions)
		if servers.length==0
			Output.puts "No servers specified (use addserver)"
		end
		@hastimeout     = false	
		@concurrent     = false
		@timeoutseconds = 30
		@servers=servers
		@command=command
		@sshcmd = "ssh"
		@threads = Array.new()
		@killed = false
		@options = globaloptions
	end

	def run
		Signal.trap("INT") do
			Output.puts("STOPPED")
			@killed = true
			sleep(1)
			@threads.each do |x| 
				begin
					x.kill
				rescue
				end
			end
		end
		if @concurrent
			runconcurrent()
		else
			runserial()
		end				

	end

	def runconcurrent
		@threads = []
		@servers.each do |host|
			#thecmd = @sshcmd + " #{host} '" + @command + "'"
			thecmd=getcmd(host,@command)
			#Output.puts thecmd
			anio = IO.popen(thecmd,"r")
			@threads << Thread.new(anio) do |theio|
				reading = true
				while reading and not @killed
					if @hastimeout
						begin
							# probably very inefficient... but it works for now :-)
							Timeout.timeout(@timeoutseconds) do
								line = theio.gets	
							end
						rescue Timeout::Error => bang
							Output.puts "Timeout"
							reading = false
							break;
						end
					else
						line = theio.gets
					end	

					if line.nil?
						reading = false
						break
					end
					if @options["nohostname"]
						Output.puts "#{line}"
					else
						Output.puts "#{host}> #{line}"
					end
				end
			end
		end

		@threads.each do |t|
			t.join
		end
	end

	def runserial
		@servers.each do |host|
			if @killed 
				return
			end
			#thecmd = @sshcmd + " #{host} '" + @command + "'"
			thecmd = getcmd(host,@command)
			#Output.puts thecmd
			anio = IO.popen(thecmd,"r")
			reading = true	
			while reading and not @killed
				if @hastimeout
					begin
						# probably very inefficient... but it works for now :-)
						Timeout.timeout(@timeoutseconds) do
							line = anio.gets	
						end
					rescue Timeout::Error => bang
						Output.puts "Timeout"
						reading = false
						break;
					end
				else
					line = anio.gets
				end	

				if line.nil?
					reading = false
					break
				end
				if @options["nohostname"]
					Output.puts "#{line}"
				else
					Output.puts "#{host}> #{line}"
				end
			end
		end

	end
end

class SSHCmdExec < CmdExecBase
	def getcmd(server,cmdstring)
		return "ssh " + server + " '" + cmdstring + "' 2>&1"
	end
end

# I don't want this to turn into another ftp like client...
# but very basic file copying is ok I guess
class SCPCmdExec < CmdExecBase
	attr_reader :localfile, :remotefile
	attr_writer :localfile, :remotefile

	def getcmd(server,cmdstring)
		# hmm.. not the best design with just the cmdstring... 
		return "scp #{localfile} #{server}:#{remotefile}"
	end
end


