#!/usr/bin/ruby
#
# RbPhoto - Ruby Photo Database
#
# Copyright (C) 2002 Taku YASUI <tach@debian.or.jp>, All Rights Reserved.
#
# This software is distribured under the GNU General Public Licence.

require 'cgi'
require 'erb/erbl'

CONVERT = '/usr/bin/convert'
PHOTODIR = ENV[HOME] + '/public_html/Photos'
THUMBNAIL = '.tn'
TN_WIDTH = '120'
TN_HEIGHT = '90'
LANG = 'ja'
CHARSET = 'euc-jp'

rhtml = {}

class Photos

  class Photo

    def initialize(filename)
      @filename = (filename).untaint
      @tn_filename = (File.dirname(@filename) + '/' + THUMBNAIL + '/' + File.basename(@filename, '.jpg') + THUMBNAIL + '.jpg').untaint
      if ( ! File.exist?(@tn_filename) )
	system("#{CONVERT} -size #{TN_WIDTH}x#{TN_HEIGHT} #{@filename} #{@tn_filename}")
      end
    end

    def to_s
      return @filename
    end

    def to_htmlsrc
      ret = '<a href="' + File.basename(@filename) + '">'
      ret += '<img src="' + THUMBNAIL + '/' + File.basename(@tn_filename) + '"'
      ret += ' border="0" alt="PHOTO:' + File.basename(@filename, '.jpg') + '"'
      ret += ' width="' + TN_WIDTH + '" height="' + TN_HEIGHT + '">'
      ret += '</a>'
      return ret
    end

    def get_caption
      ret = File.basename(@filename)
      if ( /(\d+\-\d+\-\d+)\+(\d+)-(\d+)-(\d+)/ =~ ret )
        ret = "#{$1} #{$2}:#{$3}:#{$4}"
      end
      return ret
    end

    def next
    end

    def previous
    end

  end

  # initialize and print (that's all ^^;)
  def initialize(rhtml)
    @cgi = CGI.new
    @path = CGI.unescape(@cgi.params.keys[0]).gsub(/ /, '+')
    @tn_dir = (PHOTODIR + '/' + @path + '/' + THUMBNAIL).untaint
    @files = []
    if ( /\// =~ @path )
      print self.newPhoto(@path).htmlPage
    else
    end
    files = self.getPhotos
    if ( ! files.empty? )
      mkdir(#{@tn_dir}) if ( ! File.directory?(@tn_dir) )
      files.sort.each do |file|
	@files.push(Photos::Photo.new(file))
      end
      print @cgi.header({ 'type' => "text/html; charset=#{CHARSET}" })
      print ERbLight.new(rhtml['main']).result(binding)
    else
      print @cgi.header({ 'type' => "text/html; charset=#{CHARSET}" })
      print ERbLight.new(rhtml['none']).result(binding)
    end
  end

  def getPhoto
  end

  def getPhotos
    dir = (PHOTODIR + '/' + @path + '/*.jpg').untaint
    return Dir.glob(dir)
  end

end

rhtml['none'] = <<_EOT
<html lang="#{LANG}">
<head>
<title>No such photo(s)</title>
</head>
<body>
<h1>No such photo(s)</h1>
</body>
</html>
_EOT

rhtml['main'] = <<_EOT
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="<%= LANG %>">
<head>
<meta name="Content-Language" content="<%= LANG %>">
<meta http-equiv="Content-Style-Type" content="text/css">
<meta http-equiv="Content-Script-Type" content="text/javascript">
<meta http-equiv="Content-Type" content="text/html; charset=<%= CHARSET %>">
<link rev="MADE" href="mailto:tach-at-sourceforge.jp">
<link rel="INDEX" href="http://rbphoto.sourceforge.jp/">
<link rel="CONTENTS" href="http://rbphoto.sourceforge.jp/">
<title><%= @path %> の写真リスト</title>
</head>
<body>
<h1><%= @path %> の写真リスト</h1>
<table border="0" summary="<%= @path %> の写真リスト" class="photos">
<% p_count = 0 %>
<% @files.each do |file| %>
  <% p_count = p_count + 1 %>
  <% if ( p_count % 4 == 1 ) %><tr><% end %>
  <td class="photos">
    <%= file.to_htmlsrc %><br>
    <strong><%= file.get_caption %></strong>
  </td>
  <% if ( p_count % 4 == 0 ) %></tr><% end %>
<% end %>
</table>
<hr noshade>
<address>
Created by <a href="http://rbphoto.sourceforge.jp/">rbphoto</a>
</address>
</body>
</html>
_EOT
Photos::new(rhtml)
