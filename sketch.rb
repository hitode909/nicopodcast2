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
    attr_accessor :items, :title
    def initialize(rule)
      @items = []
    end

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

    def title
      'title'
    end

    def link
      'link'
    end

    def language
      'ja-jp'
    end

    def copyright
      'copyright'
    end

    def subtitle
      'subtitle'
    end

    def author
      'author'
    end

    def summary
      'summary'
    end

    def description
      'description'
    end

    def image
      'image'
    end

    def categories
      []
    end
  end

  class Video
    attr_reader :video
    def initialize(vp)
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

    def title
      @video.title
    end

    def inspect
      "\#<Video:#{@video.video_id} #{@video.title}>"
    end

    def author
      'author'
    end

    def subtitle
      'subtitle'
    end

    def summary
      'summary'
    end

    def enclosure_url
      'enclosure_url'
    end

    def enclosure_length
      'enclosure_length'
    end

    def enclosure_type
      'enclosure_type'
    end

    def guid
      'guid'
    end

    def published_at
      'published_at'
    end

    def duration
      'duration'
    end

    def keywords
      []
    end
  end

end


# ----------------------

podcast = NicoPodcast::Podcast.new(nil)
podcast.items = NicoPodcast.agent.search('capsule').videos.map{ |vp|
  NicoPodcast::Video.new(vp)
}
# pp podcast.items
puts podcast.publish
