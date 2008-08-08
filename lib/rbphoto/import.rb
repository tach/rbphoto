#!/usr/bin/ruby
#
# RbPhoto library for Importing
# Copyright (C) 2008 Taku YASUI <tach@debian.or.jp>
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
require 'exif'
require 'gettext'
require 'gtk2'
require 'rbphoto'

class Exif
  def datetime
    self.each_entry do |name, value|
      return value if name.match(/^Date and Time/)
    end
  end
end

class RbPhoto
  class Import
    include GetText
    bindtextdomain("rbphoto")

    def initialize(args)
      @args = args
      @fileopts = {:verbose => @args['verbose'], :noop => @args['no_act']}
      @postfix = '-' + ENV['USER']

      if ( @args['version'] )
        print self.version
        exit
      elsif ( @args['help'] )
        print self.help
        exit
      end
      @dstdir = ARGV.pop
      @target = self.prepare_target(ARGV)
      @postfix = "-#{@args['photographer']}" if ( @args['photographer'] )
      self.copy
    end

    def show_error(str)
      STDERR.puts(str)
    end

    def show_log(str)
      puts(str)
    end

    def prepare_target(args = ARGV)
      ret = []
      args.each do |arg|
        if (File.directory?(arg))
          ret.concat(Dir.glob("#{arg}/*.{jpg,jpeg,JPG,JPEG}"))
          ret.concat(Dir.glob("#{arg}/*.{avi,AVI,mpg,MPG}")) if ( @args['with_movie'] )
        else
          ret.push(arg)
        end
      end
      return ret
    end

    def copy
      @target.each do |file|
        target_file = @args['without_rename'] ? file : self.rename(file)
        target_dir = File.dirname(target_file)

        if ( ! File.directory?(target_dir) )
          begin
            FileUtils.makedirs(target_dir, @fileopts)
          rescue => e
            show_error("ERROR: mkdir failed: #{e.to_s}")
          end
        end

        if ( @args['move'] )
          begin
            FileUtils.mv(file, target_file, @fileopts)
          rescue => e
            if ( e.is_a?(Errno::EACCES) && @args['force'] && !File.writable?(target_file))
              FileUtils.chmod(0644, target_file, @fileopts)
              retry
            end
            show_error("ERROR: mv failed: #{e.to_s}")
          end
        else
          begin
            FileUtils.cp(file, target_file, @fileopts)
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
      datedir = '/' + time.strftime('%Y-%m-%d') if ( @args['datedir'] )
      return @dstdir + datedir + "/#{time.strftime('%Y%m%d-%H%M%S')}#{@postfix}.#{suffix}"
    end
 
    def help
      return <<_EOT
Usage: #{$0} [options] src_(dir|file)[s]... target_dir
Copy photo image from src to target.  it renames photo file name
not to duplicate by its exif data.

Options:
  -D, --datedir              copy/move photos with datedir
  -f, --force                force to overwrite when move
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

    def version
      return <<_EOT
Robust Photo management tool (import) #{RbPhoto::VERSION}

Copyright (C) Taku YASUI <tach@debian.or.jp>
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
_EOT
    end

    class Options
      def initialize
        parser = GetoptLong.new(
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
            name = name.sub(/^--/, '').gsub(/-/, '_').downcase
            instance_variable_set("@#{name}", arg)
          end
        rescue
          @help = true
        end
      end
      attr_accessor :datedir :force :no_gui :help :with_movie :move :without_rename :no_act :photographer :version :verbose
    end
  end
end

# vim: set ts=2 sw=2 expandtab:
