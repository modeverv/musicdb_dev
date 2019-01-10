#! /usr/bin/env ruby
# -*-coding:utf-8 -*-
require 'bson'
require 'mongo'
require 'mongoid'
require 'kconv'
#require 'MeCab'
require 'mecab'
require 'natto'
require 'taglib'
#require 'taglib2'
require 'mp3info'
require File.dirname(__FILE__) + '/audioinfo_mod.rb'
require File.dirname(__FILE__)+'/globmodel2.rb'
require 'tempfile'
require 'pp'

=begin
module Mongoid
  module Criterion #:nodoc:
    module MapReduce
      def map_reduce(map, reduce, options = {})
        opts = {:out => {:inline => 1}, :raw => true, :query => selector}.merge(options)
        klass.collection.map_reduce(map, reduce, opts)
      end
      alias :mapreduce :map_reduce
    end
  end

end
=end
begin
  Mongoid.load!( File.dirname(__FILE__) + "/mongoid.yml",:production)
rescue
  Mongoid.configure do |config|
    config.master = Mongo::Connection.new('127.0.0.1').db('music2-mongoid2')
    # config.master = Mongo::Connection.new('localhost').db('photo-mongoid2')
    #  config.identity_map_enabled = true
  end
  puts "configure!!!"
end

class Mid
  include Mongoid::Document
  field :mids,type:Array
end

class Stored
  include Mongoid::Document
  field :midsid
  field :titles,type:Array
  field :created_at, :type => DateTime, :default => Time.now
  before_save :beforeS
  def beforeS
  end
end

class Statistics
  include Mongoid::Document
  field :name, type: String
  field :music_id,type:String
  field :kind, type: String
  field :created_at, :type => DateTime, :default => Time.now
#  index :name
#  index :kind
#  index :created_at
#  index({ name: 1, label: -1 }, { sparse: true })
#  index({ location: '2d' }, { background: true })

  def self.count
m =<<-EOT
  function(){ emit(this.music_id+"||"+this.name, { count: 1 }); }
EOT

r =<<-EOT
function(key, values){
  var sum = 0;
  values.forEach(function(value){ sum += value.count; }); 
  return { count: sum };
}
EOT
    Statistics.collection.map_reduce(m,r,{ out: 'result' }).find.sort('value.count',:desc)
#    Statistics.map_reduce(m,r).find.sort('value.count',:desc)
#    Statistics.find.sort('value.count',:desc)
  end

end

class Genremodel
  include Mongoid::Document
  field :name, type: String, :default => 'Unknown'
  field :update_at, :type => DateTime, :default => Time.now
  field :models_count ,type:Integer,default:0
#  index :name

  before_save :update_update_at

  def update_update_at
    self.update_at = Time.now
  end

  #  has_many :photomodels
  has_and_belongs_to_many :musicmodels

  def self.update_models_count
    rets = Genremodel.all
    rets.each do |e|
      e.models_count = e.musicmodels.count
      puts e.name
      e.save
    end
  end
end

class Musicmodel
  include Mongoid::Document

  field :path, type: String, :default => ''

  field :genre, type: String, :default => 'Unknown'
  field :artist,type: String, :default => 'Unknown'
  field :album, type: String, :default => 'Unknown'
  field :title, type: String, :default => ''
  field :ext , type: String, :default => 'mp3'
  field :thumb , type: String, :default => nil
  field :tag,:type => String ,:default => ''
  field :search,type: Array, :default => []
  field :update_at, :type => DateTime, :default => Time.now

#  index :path
#  index :search
#  index :artist

  has_and_belongs_to_many :genremodels

  before_save :force_utf8
  before_save :update_id3
  before_save :update_search
  before_save :update_update_at
  before_save :force_utf8_2
  before_save :debug_self

  def debug_self
    require 'pp'
    pp self
  end

  def self.search_by_genre(query,page=1,per=10)
    page = page.to_i
    per = per.to_i
    per = 1 if per < 1
    page = 1 if page < 1
    skipnum=(page-1) * per

    puts "page:#{page}"
    puts "per :#{per}"
    puts "snum:#{skipnum}"

    retcount = Musicmodel.where(:genre => query).only(:id,:album,:genre,:artist,:ext,:tag,:title,:path).size
    status = {:status => 'ok' ,:page => page,:total => retcount,:next => "no",:prev => "no",:qs => query}
    status[:next] = "yes" if retcount > page * per #TODO 境界微妙
    status[:prev] = "yes" if page > 1

    rets = Musicmodel.where(:genre => query).only(:genre,:id,:album,:artist,:ext,:tag,:title,:path)
      .skip(skipnum).limit(per).to_a
    [status,rets]
  rescue => ex
    puts ex
    [{:status => 'ng',:page => 0,:next => "no",:prev => "no"},[{}]]
  end

  def self.feeling_lucky(page,per)
    retcount = Musicmodel.all.only(:genre,:id,:album,:artist,:ext,:tag,:title,:path).size
    skipnum = rand(retcount)

    status = {:status => 'ok' ,:page => page ,:total => retcount,:next => "yes",:prev => "no",:qs => "Are You Feeling Lucky?"}

    rets = Musicmodel.all.skip(skipnum).limit(per).only(:genre,:id,:album,:artist,:ext,:tag,:title,:path).to_a
    [status,rets]
  rescue => ex
    puts ex
    [{:status => 'ng',:page => 0,:next => "no",:prev => "no"},[{}]]
  end

  def self.newest(page,per)
    skipnum=(page-1) * per

    retcount = Musicmodel.order_by(:update_at.desc).only(:genre,:id,:album,:artist,:ext,:tag,:title,:path).size
    status = {:status => 'ok' ,:page => page,:total => retcount,:next => "no",:prev => "no",:qs => "Newest"}
    status[:next] = "yes" if retcount > page * per #TODO 境界微妙
    status[:prev] = "yes" if page > 1

    rets = Musicmodel.order_by(:update_at.desc)
           .only(:genre,:id,:album,:artist,:ext,:tag,:title,:path)
           .skip(skipnum).limit(per).to_a
    #    rets.each do |e|
    #      if e.thumb.nil?
    #        e.thumb = Musicmodel.get_thumb
    #      end
    #    end
    [status,rets]
  rescue => ex
    puts ex
    [{:status => 'ng',:page => 0,:next => "no",:prev => "no"},[{}]]
  end

  def self.search(query,page=1,per=10)
    page = page.to_i
    per = per.to_i
    per = 1 if per < 1
    page = 1 if page < 1
    skipnum=(page-1) * per

    if query == "FeelingLucky"
      return Musicmodel.feeling_lucky(page,per)
    end

    if query == "+new"
      return Musicmodel.newest(page,per)
    end

    qs2 = query.gsub('<OR>','|').split('|').join(' ')

##     txt = qs2.downcase
##     nm = Natto::MeCab.new
##     nm.parse(txt) do |n|
##       x = ""
##       begin
##         x = n.surface
##       rescue => e
##         pp e
##       end
##       a << x
##     end

    keywords = MeCab::Tagger.new("-Owakati").parse(qs2).split(' ').map{|e| /^#{e.downcase}/}

    retcount = Musicmodel.where(:search.all => keywords).only(:genre,:id,:album,:artist,:ext,:tag,:title,:path).size
    status = {:status => 'ok' ,:page => page,:total => retcount,:next => "no",:prev => "no",:qs => query}
    status[:next] = "yes" if retcount > page * per #TODO 境界微妙
    status[:prev] = "yes" if page > 1

    rets = Musicmodel.where(:search.all => keywords).only(:genre,:id,:album,:artist,:ext,:tag,:title,:path)
      .skip(skipnum).limit(per).to_a
    #    rets.each do |e|
    #      if e.thumb.nil?
    #        e.thumb = Musicmodel.get_thumb
    #      end
    #    end
    [status,rets]
  rescue => ex
    puts ex
    [{:status => 'ng',:page => 0,:next => "no",:prev => "no"},[{}]]
  end

  def force_utf8
    self.genre = self.genre.scrub.toutf8
    self.artist= self.artist.scrub.toutf8
    self.album = self.album.scrub.toutf8
    self.ext   = File.extname(self.path).gsub('.','').downcase.toutf8
    self.tag   = self.tag.scrub.toutf8
    self.title = self.title.scrub.toutf8
  end

  def force_utf8_2
#    self.path  = self.path.toutf8
  end

  def update_update_at
#    puts "update_update_at"
    self.update_at = Time.now
  end

  def update_search
#    puts "update_search"
    mecab = MeCab::Tagger.new("-Owakati")
    a = []
    txt = "#{self.path} #{self.genre} #{self.artist} #{self.album} #{self.title} #{self.ext} #{self.tag}".downcase
    nm = Natto::MeCab.new
    nm.parse(txt) do |n|
      x = ""
      begin
        x = n.surface
      rescue => e
        pp e
      end
      a << x
    end
    begin
      emit = mecab.parse("#{self.path.scrub} #{self.genre.scrub} #{self.artist.scrub} #{self.album.scrub} #{self.title.scrub} #{self.ext.scrub} #{self.tag.scrub}".scrub.downcase).split(' ').uniq
    rescue => ex
      emit = a
    end
    self.search = emit
#    puts "end update_search"
  end

  def update_tag(args)
    args[:string] = args[:string] ||= ''
    args[:mode] = args[:mode] ||= 'single'
   
    #string is tags string separated by space
    if args[:mode] == 'single'
      self.tag = args[:string]
      set_search
      self.save
      return
    end
    
    if args[:mode] == 'multi'
      tags = args[:string].split(' ')
      tags_orig = self.tag.split(' ')
      tags_ret = tags | tags_orig
      self.tag = tags_ret.join(' ')
      set_search
      self.save
      return 
    end
  end
  
  def debug(s)
#    require 'pp'
#    pp s
  end
  
  def update_id3

    puts "#################\nself.path => #{self.path}"
    # opener = "\"#{self.path.gsub(' ','\ ')}\""

    if File.extname(self.path).downcase != '.wav'
##        begin #audioinfo is slow. use taglib2
##          if self.title == '' # is fail by taglib2
##            puts "try taglib2"
##            tag = ::TagLib2::File.new(self.path.to_str)
##            self.genre  = tag.genre.to_s.toutf8  if tag.genre
##            self.artist = tag.artist.to_s.toutf8 if tag.artist
##            self.album  = tag.album.to_s.toutf8  if tag.album
##            self.title  = tag.title.to_s.toutf8  if tag.title
##  #          if tag.image
##  #            path = nil
##  #            tmp = Tempfile.open(['tm','image'],'/tmp') do |io|
##  #              io.puts "#EXTM3U"
##  #              io.puts tag.image.data
##  #              path = io.path
##  #            end
##  #            buff_m = `convert -define jpeg:size=200x200 -resize 200x200 -quality 90 -strip "#{path}" -`
##  #            self.thumb = [buff_m].pack('m')
##  #          end
##          end
##        rescue => ex
##          puts "tablib2"
##          p ex
##        ensure
##          buff_m = nil
##        end

      begin
        if self.title == ''
          taglib_class = {'.mp3' => TagLib::MPEG::File, '.m4a' => TagLib::MP4::File, '.flac' => TagLib::FLAC::File ,'.ogg' => TagLib::Ogg::Vorbis::File }
#          puts "try taglib"
          pp self.path
          taglib_class[File.extname("#{self.path}").downcase].open(self.path) do |f|
            self.genre  = f.tag.genre.to_s.scrub.toutf8  if f.tag.genre
            self.artist = f.tag.artist.to_s.scrub.toutf8 if f.tag.artist
            self.album  = f.tag.album.to_s.scrub.toutf8  if f.tag.album
            self.title  = f.tag.title.to_s.scrub.toutf8  if f.tag.title
          end
        end
      rescue => ex
        puts "taglib"
        p ex
      ensure
        buff_m = nil
      end

##       begin
##         if self.title == '' # is fail by taglib2
##           puts "try audioinfo"
##           AudioInfo.open("#{self.path}") do |tag|
##             debug tag.to_h  # { "artist" => "artist", "title" => "title", etc... }
##             self.genre  = tag.genre.to_s.toutf8  if tag.genre
##             self.artist = tag.artist.to_s.toutf8 if tag.artist
##             self.album  = tag.album.to_s.toutf8  if tag.album
##             self.title  = tag.title.to_s.toutf8  if tag.title
##           end
##         end
##       rescue AudioInfoError => ex
##         p ex
##         p tag
##       rescue =>ex
##         puts "ex try audioinfo"
##         pp ex
##         pp tag
##       end

##       begin
##         if self.title == ''
##           puts "try mp3info"
##           Mp3Info.open("#{self.path}") do |mp3|
##             tag = mp3.tag
##             self.genre  = tag.genre.to_s.toutf8  if tag.genre
##             self.artist = tag.artist.to_s.toutf8 if tag.artist
##             self.album  = tag.album.to_s.toutf8  if tag.album
##             self.title  = tag.title.to_s.toutf8  if tag.title
##           end
##         end
##       rescue => ex
##         puts "mp3info"
##         p ex
##       end
    end

    begin
      if self.title == '' #is fail by taglib2 and audioinfo
        self.title = File.basename(self.path).gsub(File.extname(self.path),'').toutf8
      end
    rescue => ex
      pp "title"
      pp ex
    end

    begin
      if self.album.downcase == 'unknown' || self.album == ''
        self.album = File.basename(File.dirname(self.path))
      end
    rescue => ex
      pp "album"
      pp ex
    end

    begin
      if self.artist.downcase == 'unknown' || self.artist == ''
        self.artist = File.basename(File.dirname(File.dirname(self.path)))
      end
    rescue => ex
      pp "artist"
      pp ex
    end

    self.genre  = "Unknown" if self.genre == ""

#    puts "end of update_id3"
  end

  def get_thumb
    if self.thumb.nil?
      return Musicmodel.get_thumb
    end
    self.thumb
  end
  
  @buf = "data:image/jpeg;base64,#{[File.open(File.dirname(__FILE__) + '/default.jpg','rb').read].pack('m')}"
  
  class << self

    def get_thumb
      @buf
    end
    
    def deug(a)
      require 'pp'
      pp a
    end

    def _update_db entries
##      5.times do
#        threads << Thread.new do 
#          begin
#            loop do
#              entry = entries.shift
#              break if entry.nil?
#              chk_and_handle_file(entry)
#            end 
#          rescue => ex
#            p ex
#          end  
#        end
##      end
      #      threads
       entries.each do |e|
          begin
#            loop do
#              entry = entries.shift
#              break if entry.nil?
#              chk_and_handle_file(entry)
            #            end
            chk_and_handle_file(e)
          rescue => ex
            p ex
          end  
         end
    end
    
    def datas(args = {})
      folders = args[:folders] ||= [
#                                     "/var/smb/sdb1/music/iTunesMac/BAIDOKU",
#                                     "/var/smb/sdb1/music/iTunes1",
#                                     "/var/smb/sdb1/music/iTunes2",
#                                     "/var/smb/sdb1/music/iTunes3",
#                                     "/var/smb/sdb1/music/iTunes2011",
#                                     "/var/smb/sdb1/music/iTunesMac",
#                                     "/var/smb/sdb1/music/iTunesLossless",
#                                     "/var/smb/sdb1/video2/作成",
#                                     "/var/smb/sdb1/music/iTunes2012",
#                                     "/var/smb/sdb1/music/iTunes2013",
#                                     "/var/smb/sdb1/music/iTunes2014",
                                     "/var/smb/sdb1/music",
#                                     "/var/smb/sdb1/music/iTunes2015",
                                     "/var/smb/sdb1/music/iTunes2016",
#                                    "/var/smb/sdb1/music"
                                   ]
      ext = args[:ext] ||= [
                            'MP3',
                            'M4A',
                            'WAV',
                            'MKA',
                            'APE',
                            'FLAC',
                            'WMA',
                            'OGG',                          
                           ]
      [folders,ext]
    end

    def globes
#      @files = []
#      @folders,@ext = datas
#      p @folders
#      p @ext
#      count = 0
#      @folders.each do |p|
#        @ext.each do |e|
#          Dir.glob("#{p}/**/*.#{e}") do |element|
#            @files << { 'path' => element }
#          end
#          
#          Dir.glob("#{p}/**/*.#{e.downcase}") do |element|
#            @files << { 'path' => element }
#          end
#
#          Dir.glob("#{p}/**/*.#{e.capitalize}") do |element|
#            @files << { 'path' => element }
#          end
# 
#        end
      #      end
      @files = GlobServerFiles.glob
      return @files
    end

    def update_db
#      debug_delete_all
      
      delete_not_exist_entry # 不要
      
      #entries = globes
      entries = GlobServerFiles.new
      entries.each do |e|
        begin
          chk_and_handle_file(e)
        rescue => ex
          p ex
        end  
      end
      
#p entries.size;return;
#      threads = []
#
#      threads = _update_db(entries[0,10000],threads)
#      threads = _update_db(entries[10000,10000],threads)
#      threads = _update_db(entries[20000,10000],threads)
#      threads = _update_db(entries[30000,10000],threads)
#      threads = _update_db(entries[40000,10000],threads)
#      threads = _update_db(entries[50000,10000],threads)
#      threads = _update_db(entries[60000,10000],threads)
#      threads = _update_db(entries[70000,10000],threads)
#      threads = _update_db(entries[80000,10000],threads)
#      threads = _update_db(entries[90000,10000],threads)
#      threads = _update_db(entries[100000,10000],threads)
#      
#      threads.each do |t|
#        t.join
      #      end
#      _update_db(entries)
      Genremodel.update_models_count
    end

    def debug_delete_all
      puts "debug_delete_all"
      Musicmodel.all.each do |e|
        e.delete
      end
      Genremodel.all.each do |e|
        e.delete
      end
   end
    
    def delete_not_exist_entry
       rets = Musicmodel.all.only(:id,:path,:genremodels)
       rets.each do |music|
         puts "#{music.id} => #{music.path}"
         if !File.exists?(music.path)
           puts "not exist"
          music.genremodels.all do |genre|
             genre.musicmodels.find(music.id).delete
           end
           music.delete
         end
       end
    end


    def chk_and_handle_file(entry)
      puts "chk_and_handle_file:#{entry}"
#return
      detecta = Musicmodel.where(:path => entry.to_s).first

      if !detecta.nil?
        return entry
      end

      if detecta.nil?
        #new musicmodel
        detecta = Musicmodel.
          new(
              :path    => entry.to_s,
              )
        detecta.save
      end

      a_genre = Genremodel.where(:name => detecta.genre).first

      if a_genre.nil?
        a_genre = Genremodel.new(:name => detecta.genre)
        a_genre.save
      end

      if a_genre.musicmodels.where(:id => detecta.id).first.nil?
        a_genre.musicmodels << detecta
        a_genre.save
      end
      
      a_genre.save
      
#      entry['musicmodel'] = detecta
#      entry['genremodel'] = a_genre
      return entry
    end
  end
    
   
end

