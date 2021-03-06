#!/usr/bin/ruby
#
# RbPhoto library for Importing
#
# Copyright (C) 2008-2009 Taku YASUI <tach@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# $Id$

require 'getoptlong'
require 'fileutils'
require 'find'
require 'exif'
require 'gettext'
require 'rbphoto'

class Exif
  def datetime
    [' (original)', ' (digitized)', ''].each do |suf|
      val = self['Date and Time' + suf]
      val && val.match(/^\d+:\d+:\d+ \d+:\d+:\d+$/) or next
      return val
    end
    return false
  end
end

class RbPhoto
  class Import
    include GetText
    bindtextdomain("rbphoto")
 
    def self.help
      return <<_EOT
Usage: #{$0} [options] src_(dir|file)[s]... target_dir
Copy photo image from src to target.  it renames photo file name
not to duplicate by its exif data.

Options:
  -a, --all                  set all recommended options; same as -DmM
  -D, --datedir              copy/move photos with datedir
  -f, --force                force to overwrite when move
  -G, --no-gui               disable GTK2+ graphical interface
  -m, --move                 move photos instead of copy
  -M, --with-movie           process not only images but also movies
  -N, --without-rename       do not rename photo files
  -p, --photographer=id      set photographer id (default: $USER)
  -n, --no-act               do not copy/move only test
  -h, --help                 show this help
  -v, --verbose              make verbose output
  -V, --version              show software version
_EOT
    end

    def self.version
      return <<_EOT
Robust Photo management tool (import) #{RbPhoto::VERSION}

Copyright (C) Taku YASUI <tach@debian.or.jp>
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
_EOT
    end

    def initialize(opt)
      @opt = opt
    end

    def show_error(str)
      STDERR.puts(str)
    end

    def show_log(str)
      puts(str)
    end

    def prepare_target(args = ARGV)
      @target = []
      args.each do |arg|
        if (File.directory?(arg))
          Find.find(arg) do |f|
            if ( f.match(/\.jpe?g$/i) )
              @target.push(f)
            elsif ( f.match(/\.(?:avi|mpe?g)$/i) && @opt.with_movie )
              @target.push(f)
            end
          end
        else
          @target.push(arg)
        end
      end
      return @target.size > 0 ? @target.size : false
    end

    def execute
      @fileopts = { :verbose => @opt.verbose, :noop => @opt.no_act }
      @postfix = '-' + @opt.photographer
      count = 0
      @target.each do |file|
        target_file = @opt.without_rename ? file : self.rename(file)
        target_dir = File.dirname(target_file)

        if ( ! File.directory?(target_dir) )
          begin
            FileUtils.makedirs(target_dir, @fileopts)
          rescue => e
            show_error("ERROR: mkdir failed: #{e.to_s}")
          end
        end

        if ( @opt.move )
          begin
            FileUtils.mv(file, target_file, @fileopts)
            count += 1
          rescue => e
            if ( e.is_a?(Errno::EACCES) && @opt.force && !File.writable?(target_file))
              FileUtils.chmod(0644, target_file, @fileopts)
              retry
            end
            show_error("ERROR: mv failed: #{e.to_s}")
          end
        else
          begin
            FileUtils.cp(file, target_file, @fileopts)
            count += 1
          rescue => e
            show_error("ERROR: cp failed: #{e.to_s}")
          end
        end
        begin
          FileUtils.chmod(0444, target_file, @fileopts)
        rescue => e
          show_error("ERROR: chmod failed: #{e.to_s}")
        end
      end
      return count
    end

    def rename(filename)
      datedir = ''
      suffix = ''
      time = Time.at(0)
      case File.extname(filename)
      when /^\.avi$/i
        suffix = 'avi'
        time = File.mtime(filename)
      when /^\.mpe?g$/i
        suffix = 'mpg'
        time = File.mtime(filename)
      when /^\.jpe?g$/i
        suffix = 'jpg'
        begin
          exif = Exif.new(filename)
          time = Time.local(*exif.datetime.split(/[:\s]/))
        rescue
          show_error("Cannot read exif data correctly: #{filename}")
          return @dstdir + "/#{File.basename(filename, '.*')}#{@postfix}.#{suffix}"
        end
      else
        show_error("Unsupported filetype: #{filename}")
        return @dstdir + "/#{filename}"
      end
      datedir = '/' + time.strftime('%Y-%m-%d') if ( @opt.datedir )
      return @dstdir + datedir + "/#{time.strftime('%Y%m%d-%H%M%S')}#{@postfix}.#{suffix}"
    end

    def help
      self.class.help
    end

    def version
      self.class.version
    end

    class Options < Hash
      def initialize
        parser = GetoptLong.new(
          ['--all',             '-a', GetoptLong::NO_ARGUMENT],
          ['--datedir',         '-D', GetoptLong::NO_ARGUMENT],
          ['--force',           '-f', GetoptLong::NO_ARGUMENT],
          ['--no-gui',          '-G', GetoptLong::NO_ARGUMENT],
          ['--help',            '-h', GetoptLong::NO_ARGUMENT],
          ['--with-movie',      '-M', GetoptLong::NO_ARGUMENT],
          ['--move',            '-m', GetoptLong::NO_ARGUMENT],
          ['--without-rename',  '-N', GetoptLong::NO_ARGUMENT],
          ['--no-act',          '-n', GetoptLong::NO_ARGUMENT],
          ['--photographer',    '-p', GetoptLong::REQUIRED_ARGUMENT],
          ['--version',         '-V', GetoptLong::NO_ARGUMENT],
          ['--verbose',         '-v', GetoptLong::NO_ARGUMENT])
        begin
          parser.each do |name, arg|
            arg = true if (arg == "")
            case name
            when '--all'
              self['datedir'] = true
              self['move'] = true
              self['with_movie'] = true
            else
              self[name.sub(/^--/, '').gsub(/-/, '_').downcase] = arg
            end
          end
          self['photographer'] ||= ENV['USER']
        rescue
          self['help'] = true
        end
      end

      def method_missing(name, arg=nil)
        if ( name.to_s.match(/^(.+)=$/) )
          self[$1] = arg
        else
          return self[name.to_s]
        end
      end
    end
  end
end

# vim: set ts=2 sw=2 expandtab:
