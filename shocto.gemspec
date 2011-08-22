#!/usr/local/bin/ruby
require 'rubygems'

SPEC = Gem::Specification.new do |s|
	s.name="Shocto"
	s.version="0.5"
	s.author="David Parfitt"
	s.email="diparfitt@gmail.com"
	s.homepage="http://github.com/metadave/shocto"
	s.platform=Gem::Platform::RUBY
	s.summary="A shell that allows you to work on many servers at once"
	candidates=Dir.glob("{bin,docs,lib}/**/*")
	s.files = candidates.delete_if do |item|
			item.include?("CVS") || item.include?("rdoc")
		end
	s.require_path="lib"
	#s.autorequire="shocto"
	s.has_rdoc=false
	s.bindir="bin"
	s.executables << 'shocto'
end
