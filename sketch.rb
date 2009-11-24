# -*- coding: utf-8 -*-
require 'pit'
require 'module/nicovideo/lib/nicovideo'
require 'nkf'
require "rss/maker"

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
      rss = RSS::Maker.make('2.0') do |maker|
        maker.channel.title = self.title
        maker.channel.description = self.description
        maker.channel.link = self.link
        maker.channel.itunes_image = self.image
        maker.channel.language = self.language
        maker.items.do_sort = true
        self.items.each do |source|
          maker.items.new_item do |item|
            item.link = source.info.watch_url
            item.title = source.title
            item.description = source.info.description
            item.date = source.info.first_retrieve
            item.itunes_duration = source.duration
            item.enclosure.url = source.enclosure_url
            item.enclosure.length = source.enclosure_length
            item.enclosure.type = source.enclosure_type
          end
        end
      end

      return rss.to_s
    end

    def content
    end

    def language
      'ja-jp'
    end

    def image
      self.items.each{ |i|
        return i.thumbnail rescue next
      }
      ""
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
      File.exist?(self.original_path)
    end

    def has_enclosure?
      File.exist?(self.path('mp3')) and File.exist?(self.path('mp4'))
    end

    def download
      puts "download #{self.inspect} (#{@video.info.size_high / 1024}kb)"
      NicoPodcast.prepare_directory
      File.open(self.original_path, "wb") {|f|
        f.write @video.video
      }
    end

    def encode
      if NicoPodcast.output_type == 'mp3'
        puts "encode #{self.inspect} mp3"
        (system "ffmpeg -i #{self.original_path} -acodec libmp3lame -ab 128k -ac 2 #{self.path('mp3')} > /dev/null" ) unless File.exist?(self.path('mp3'))
      end
      if NicoPodcast.output_type == 'mp4'
        puts "encode #{self.inspect} mp4"
        (system "ffmpeg -i #{self.original_path} -f mp4 -acodec libfaac -ac 2 -vcodec libx264 -vpre default #{self.path('mp4')} > /dev/null" or File.unlink(self.path('mp4'))) unless File.exist?(self.path('mp4'))
      end
    end

    def path(type = @video.type)
      suffix = type ? ".#{type}" : ''
      File.join(NicoPodcast.file_path, @video.video_id + suffix)
    end

    def original_path
      suffix = "_original.#{@video.type}"
      File.join(NicoPodcast.file_path, @video.video_id + suffix)
    end

    def info
      @video.info
    end

    def inspect
      "\#<Video:#{@video.video_id}>"
    end

    def title
      NKF.nkf('-w', @video.title)
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

NicoPodcast.root_url = "http://localhost/~#{ENV['USER']}/podcast/"
NicoPodcast.output_path = '~/Sites/podcast'
podcast = NicoPodcast::Podcast::Search.new
key = 'PV'
search = NicoPodcast.agent.search(key)
podcast.link = search.url
search.videos.map{ |vp|
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
