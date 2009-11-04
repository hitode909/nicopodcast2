# -*- coding: utf-8 -*-
require 'pp'
require 'pit'
require 'module/nicovideo/lib/nicovideo'
require 'erb'

module NicoPodcast
  def self.output_path
    @@output_path ||= './podcast'
  end
  def self.output_path=(a)
    @@output_path = a
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

  class NicoPodcast <Podcast
    def process
      prepare_items
      publish
    end

    def prepare_items
      @items.each{ |item|
        begin
          puts item.title
          item.prepare
        end
      }
      return
    end

    def publish
      podcast = self
      template = open('template.xml')
      ERB.new(template.read).result(binding)
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
      puts "download #{@video.info.size_high / 1024}kb"
      NicoPodcast.prepare_directory
      File.open(self.path, "wb") {|f|
        f.write @video.video
      }
    end

    def encode
      puts 'encode mp3'
      system "ffmpeg -i #{self.path} -acodec libmp3lame -ab 128k #{self.path('mp3')} > /dev/null" unless File.exist?(self.path('mp3'))
      puts 'encode mp4'
      system "ffmpeg -i #{self.path} -f mp4 -acodec libfaac -async 4800 -dts_delta_threshold 1 -vcodec libx264 -qscale 7 #{self.path('mp4')} > /dev/null" unless File.exist?(self.path('mp4'))
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

    def enclosure_url(type = 'mp3')
      File.join(NicoPodcast.root_url, NicoPodcast.file_directory, @video.video_id + suffix)
    end

    def enclosure_length
      @video.info.size_high
    end

    def enclosure_type
      'enclosure_type'
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

NicoPodcast.root_url = 'http://exampple.com/podcast/'
podcast = NicoPodcast::NicoPodcast.new
key = 'capsule'
search = NicoPodcast.agent.search(key)
podcast.title = key
podcast.description = "#{key}の検索結果"
podcast.link = search.url
search.videos.map{ |vp|
  begin
    i = NicoPodcast::Video.new(vp)
    i.info
    podcast.items << i
  rescue
  end
}
puts podcast.process
