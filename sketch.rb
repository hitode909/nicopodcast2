# -*- coding: utf-8 -*-
require 'pp'
require 'pit'
require 'module/nicovideo/lib/nicovideo'
require 'erb'
require 'thread'

module NicoPodcast
  def self.output_path
    @@output_path ||= './podcast'
  end
  def self.output_path=(a)
    @@output_path = File.expand_path(a)
  end

  def self.output_type
    @@output_type ||= 'mp3'
  end
  def self.output_type=(a)
    @@output_type = a
  end

  def self.file_directory
    @@file_directory ||= 'files'
  end
  def self.file_directory=(a)
    @@file_directory = a
  end

  def self.root_url
    @@root_url
  end

  def self.root_url=(a)
    @@root_url = a
  end

  def self.file_path
    File.join(self.output_path, self.file_directory)
  end

  def self.prepare_directory
    Dir.mkdir self.output_path unless File.directory? self.output_path
    Dir.mkdir self.file_path unless File.directory? self.file_path
  end

  def self.agent
    config = Pit.get('nicopodcast', :require => {
        'email'    => 'email in nicovideo',
        'password' => 'password in nicovideo',
      })
    @agent ||= Nicovideo.new(config['email'], config['password'])
  end

  class Podcast
    attr_accessor :items, :title, :link, :language, :copyright, :subtitle, :author, :summary, :description, :image, :categories

    def initialize
      @items = []
    end
  end

  class Podcast::Search <Podcast
    def process
      prepare_items
      publish
    end

    def prepare_items
      @items = @items.map{ |item|
        begin
          item.prepare
          item
        rescue => e
          p e
          nil
        end
      }.compact
      return
    end

    def publish
      rss = RSS::Rss.new( "0.9" )
      channel = RSS::Rss::Channel.new
      channel.title = self.title
      channel.description = self.description
      channel.link = self.link
      channel.language = self.language
      rss.channel = channel

      image = RSS::Rss::Channel::Image.new
      image.url = self.image
      image.title = self.title
      image.link = self.link
      channel.image = image

      self.items.each do |source|
        item = RSS::Rss::Channel::Item.new
        item.title = source.title
        item.link = source.info.watch_url
        item.enclosure = RSS::Rss::Channel::Item::Enclosure.new(
          source.enclosure_url, source.enclosure_length, source.enclosure_type )
        channel.items << item
      end
      puts rss.to_s
      return rss.to_s
    end

    def content
    end

    def language
      'ja-jp'
    end

    def image
      self.items.first.thumbnail
    end
  end

  class Item
    attr_accessor :title, :author, :subtitlel, :summary, :enclosure_url, :enclosure_length, :enclosure_type, :guid, :published_at, :duration, :keywords

    def initialize
      @keywords = []
    end

    def guid
      self.enclosure_url
    end
  end

  class Video < Item
    attr_reader :video
    def initialize(vp)
      @keywords = []
      @video = vp
    end

    def prepare
      download unless has_source?
      encode unless has_enclosure?
    end

    def has_source?
      File.exist?(self.path)
    end

    def has_enclosure?
      File.exist?(self.path('mp3')) and File.exist?(self.path('mp4'))
    end

    def download
      puts "download #{self.title} (#{@video.info.size_high / 1024}kb)"
      NicoPodcast.prepare_directory
      File.open(self.path, "wb") {|f|
        f.write @video.video
      }
    end

    def encode
      puts "encode #{self.title} mp3"
      (system "ffmpeg -i #{self.path} -acodec libmp3lame -ab 128k #{self.path('mp3')} >& /dev/null" or File.unlink(self.path('mp3'))) unless File.exist?(self.path('mp3'))
      puts "encode #{self.title}"
      (system "ffmpeg -i #{self.path} -f mp4 -acodec libfaac -async 4800 -dts_delta_threshold 1 -vcodec libx264 -qscale 7 #{self.path('mp4')} >& /dev/null" or File.unlink(self.path('mp4'))) unless File.exist?(self.path('mp4'))
    end

    def path(type = @video.type)
      suffix = type ? ".#{type}" : ''
      File.join(NicoPodcast.file_path, @video.video_id + suffix)
    end

    def info
      @video.info
    end

    def inspect
      "\#<Video:#{@video.video_id} #{@video.title}>"
    end

    def title
      @video.title
    end

    def author
      'author'
    end

    def summary
      @video.info.description
    end

    def enclosure_url(type = NicoPodcast.output_type)
      suffix = type ? ".#{type}" : ''
      File.join(NicoPodcast.root_url, NicoPodcast.file_directory, @video.video_id + suffix)
    end

    def enclosure_path(type = NicoPodcast.output_type)
      self.path(type)
    end

    def enclosure_length
      File.size(self.enclosure_path) rescue 0
    end

    def enclosure_type
      NicoPodcast.output_type == 'mp3' ? 'audio/mpeg' : 'video/mp4'
    end

    def published_at
      @video.info.published_at
    end

    def duration
      @video.info['length']
    end

    def thumbnail
      @video.info.thumbnail_url
    end

    def subtitle
    end

    def published_at
      @video.info.first_retrieve
    end
  end

end


# ----------------------

NicoPodcast.root_url = 'http://localhost/~fkd/podcast/'
NicoPodcast.output_path = '~/Sites/podcast'
podcast = NicoPodcast::Podcast::Search.new
key = 'PV'
search = NicoPodcast.agent.search(key)
podcast.link = search.url
search.videos[0..5].map{ |vp|
  begin
    i = NicoPodcast::Video.new(vp)
    i.info
    podcast.items << i
  rescue
  end
}
['mp3', 'mp4'].each{ |type|
  NicoPodcast.output_type = type
  podcast.title = "#{key}(#{type})"
  podcast.description = "#{key}の検索結果(#{type})"
  File.open(File.join(NicoPodcast.output_path, "#{key}_#{type}.rss"), "w") {|f|
    f.puts podcast.process
  }
}
