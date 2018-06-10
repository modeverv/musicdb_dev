# -*- coding:utf-8  -*-
class GlobServerFiles
  include Enumerable

  def initialize args={}
    @count = 0
    @folders = args[:folders] ||= [
#      "/var/smb/sdb1/music/music",


      #      "/var/smb/sdb1/music/2012_2",

      #      "/var/smb/sdb1/music/iTunes",

      #      "/var/smb/sdb1/music/iTunes1",

            "/var/smb/sdb1/music/iTunes2",

            "/var/smb/sdb1/music/iTunes2014",
      
            "/var/smb/sdb1/music/iTunes2015Mac",
      
            "/var/smb/sdb1/music/iTunes3",
      
            "/var/smb/sdb1/music/iTunesLossless",
      
            "/var/smb/sdb1/music/kujiDropBox",
      
            "/var/smb/sdb1/music/iTunes2016",
      
      "/var/smb/sdb1/music/iTunes2016/朝焼けのスターマインFLAC",
      
            "/var/smb/sdb1/music/iTunes2017",
      
      "/var/smb/sdb1/music/iTunes2018",
    ]
    @ext = args[:ext] ||= [
                           'MP3',
                           'M4A',
                           'WAV',
                           'MKA',
                           'APE',
                           'FLAC',
                           'WMA',
                           'OGG',                                                  ]
  end
  
  def self.data(args = {})
    @folders = args[:folders] ||= [
                                  "/var/smb/sdb1/video2/作成",
                                  "/var/smb/sdb1/music/iTunes1",
                                  "/var/smb/sdb1/music/iTunes2",
                                  "/var/smb/sdb1/music/iTunes3",
                                  "/var/smb/sdb1/music/iTunes2011",
                                  "/var/smb/sdb1/music/iTunes2012",
                                  "/var/smb/sdb1/music/iTunes2013",
                                  "/var/smb/sdb1/music/iTunes2014",
                                  "/var/smb/sdb1/music/iTunes2015",
                                  "/var/smb/sdb1/music/iTunes2016",
                                  "/var/smb/sdb1/music/iTunesMac",
                                  "/var/smb/sdb1/music/iTunesLossless",
                                  "/var/smb/sdb1/music/iTunesMusicMBP",
                                  ]
    @ext = args[:ext] ||= [
                           'MP3',
                           'M4A',
                           'WAV',
                           'MKA',
                           'APE',
                           'FLAC',
                           'WMA',
                           'OGG',                          
                          ]
    ret = [@folders,@ext]
    p ret
    exit
    ret 
  end

  def self.glob
    @files = []
    @filders,@ext = GlobServerFiles.data

    @folders.each do |p|
      @ext.each do |e|
        Dir.glob("#{p}/**/*.#{e}") do |element|
          @files << { 'path' => element }
        end
        Dir.glob("#{p}/**/*.#{e.downcase}") do |element|
          @files << { 'path' => element }
        end
      end
    end
    
    return @files
  end

  def each
    @folders.each do |folder|
      @ext.each do |ext|
        Dir.glob("#{folder}/**/*.#{ext.downcase}") do |element|
          @count += 1
          puts "downcase - #{@count} - #{element}"
          yield element
        end
        Dir.glob("#{folder}/**/*.#{ext}") do |element|
          @count += 1
          puts "uppercase - #{@count} - #{element}"
          yield element
        end
        
      end
    end
    
  end
  
end
