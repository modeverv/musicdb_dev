#! /usr/bin/env ruby
# -*- coding:utf-8 -*-
#Encoding.default_external = 'utf-8'
#Encoding.default_internal = 'utf-8'
require 'sinatra'
require 'padrino'
require 'sinatra/base'
#require 'padrino-core/application/routing'
require 'padrino-core'
require 'padrino-cache'
#require 'sinatra/reloader'
require 'digest'

Padrino.configure_apps do
  set :protection, false
  set :protect_from_csrf, false
end


module Sinatra
  module Xsendfile
    def x_send_file(path, opts = {})
      if opts[:type] or not response['Content-Type']
        content_type(opts[:type] || File.extname(path) || 'application/octet-stream')
      end

      if opts[:disposition] == 'attachment' || opts[:filename]
        attachment opts[:filename] || path
      elsif opts[:disposition] == 'inline'
        response['Content-Disposition'] = 'inline'
      end

      header_key = opts[:header] || (settings.respond_to?(:xsf_header) && settings.xsf_header) || 'X-SendFile'
      #      path = File.expand_path(path).gsub(settings.public, '') if header_key == 'X-Accel-Redirect'
      puts path
      response[header_key] = path

      halt
    rescue Errno::ENOENT
      not_found
    end

    def self.replace_send_file!
      Sinatra::Helpers.send(:alias_method, :old_send_file, :send_file)
      Sinatra::Helpers.module_eval("def send_file(path, opts={}); x_send_file(path, opts); end;")
    end
  end

  helpers Xsendfile
end

require File.dirname(__FILE__)+'/models'
##load File.dirname(__FILE__)+'/models.rb'
require 'cgi'
require 'mechanize'
require 'kconv'
require 'uri'
require 'json'

##########################################################################################
##########################################################################################
def get_prefix
  ""
  "/musicdb_dev"
end

Encoding.default_internal = Encoding.find("UTF-8")

class MyApp < Sinatra::Application
  set :app_name, "musicdb_dev"
  set :protection, :except => [:http_origin]

  configure :production do
    #  Sinatra::Xsendfile.replace_send_file! #replaces sinatra's send_file with x_send_file
#    set :xsf_header, 'X-Accel-Redirect' #setting default(X-SendFile) header (nginx)
    file = File.new("#{settings.root}/tmp/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end
end

class MyApp < Sinatra::Application
  register Padrino::Routing
  register Padrino::Cache

#  enable :caching

  #loggerがPadrino::loggerじゃなくなる。挙動は追いかけきれていない。
  def logger
    Padrino::logger
  end

  ### helper ##################
  require 'tilt'
  Tilt.register 'rjs', Tilt::ERBTemplate
  Tilt.register 'rcss', Tilt::ERBTemplate

  # need modify via environment
  helpers do
    def title
      "musicdb_dev"    
    end

    def get_ip
     env["X_Forwarded_For"] || env["Http_X_Forwarded_For"] || env["X_FORWARDED_FOR"] ||env["HTTP_X_FORWARDED_FOR"] || request.ip
    end
    
    def get_mechanize(args={})
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows IE 7'
#      agent.set_proxy('127.0.0.1',3128)    if args[:useproxy]
      agent
    end
    
    def get_last_fm_artist_nokogiri(artist)
      agent = get_mechanize({:useproxy => true})
      apikey = "c90a888c4d97a99f4d93f36cb1ebe0df"
      agent.get "http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=#{URI.escape artist}&api_key=#{apikey}&autocorrect=1"
      nokogiri = Nokogiri::XML(agent.page.body)
      agent.get "http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=#{URI.escape artist}&api_key=#{apikey}&autocorrect=1&lang=jp"
      nokogirija = Nokogiri::XML(agent.page.body)
      [nokogiri,nokogirija]
    end
    
    def get_similar_artist_from_last_fm(artist)
      nokogiri = get_last_fm_artist_nokogiri(artist)[0]
      similar_artists = nokogiri.xpath("//artist/similar/artist").to_a.map {|e|
        {
          :name => e.xpath('name').first.text,
          :image => e.xpath('image[@size="small"]').first.text,
        }
      } << {:name => nokogiri.xpath('//artist').first.xpath('name').first.text,
        :image => nokogiri.xpath('//artist').first.xpath('image[@size="small"]').first.text
      }
      similar_artists
    rescue
      []
    end
    #get_similar_artist_from_last_fm('Aimer')  
    def get_similar_artist_in_mongo(args)
      return [] unless args[:artist]
      lastfm_ret = get_similar_artist_from_last_fm(args[:artist])
      mongo_ret = Musicmodel.where(:artist.in => lastfm_ret.map{|e| e[:name]} ).only(:artist).distinct(:artist).to_a.sort
      #=>    ["きこう","くるり"]
      ret = []
      lastfm_ret.each do |fm|
        if mongo_ret.index(fm[:name])
          ret << fm
        end
      end
      ret
    end
    
    def make_host
      if development?
        return "#{request.host}/"
      else
        return "#{request.host}/"
      end
    end

    def recent(query)
      status = {:status => 'ok' ,:page => 1,:total => 100,:next => "no",:prev => "no",:qs => query}
      ret = Musicmodel.desc(:update_at).limit(100).to_a
      [status,ret]
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="musicdb_dev Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def ok_ip?
      flg = false
      open("/home/seijiro/sinatra/musicdb_dev/ok_ip.txt","r"){|io| 
        io.each{|line| flg = true if line.chomp != "" && get_ip =~ /#{line.chomp}/ }
      }
      throw(:halt, [403, "Sorry,Your IP(#{get_ip}) is not permited.\n"]) if flg == false
    end


    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['seijiro','hoge']
    end

    def get_tmpfile(&block)
      path = nil
      tmp = Tempfile.open(["#{Time.new.to_i.to_s}",'.m3u'],'/tmp') do |io|
        io.puts "#EXTM3U"
        io.puts yield
        path = io.path
      end
      path
    end

    def make_m3u_elem(ret)
      str = ""
      title = ret.title == "" ? File.basename(ret.path) : ret.title
      # send_file
#      str += "#EXTINF:,S#{ret.artist} - #{title}\n"
#      str += "http://#{request.host}#{get_prefix}/api/stream/#{ret.id}/file.#{ret.ext}\n"
#      str += "http://#{request.host}#{get_prefix}/api/stream/#{ret.id}/file.#{ret.ext}\n"
      
      # x_send_file no_varnish(pipe)
      #    str += "#EXTINF:1000,#{ret.artist} - #{title}\n"
      #    str += "http://#{request.host}#{get_prefix}/api/stream/#{ret.id}/file.#{ret.ext}\n"
      # x_send_file
      #    str += "#EXTINF:1000,NSX#{ret.artist} - #{title}\n"
      #    str += "http://#{request.host}:8080#{get_prefix}/api/stream/#{ret.id}/file.#{ret.ext}\n"

      # varnish(80) => nginx(8080) => node(23001)
#      str += "#EXTINF:1000,#{ret.artist} - #{title}\n"
#      str += "http://#{request.host}/stream/musicdb/#{ret.id}/file.#{ret.ext}\n"

      # varnish(:80) => node(:23001)
      str += "#EXTINF:1000,#{ret.artist} - #{title} (varnish->node)\n"
      str += "http://#{request.host}/stream/musicdb/#{ret.id}/file.#{ret.ext}\n"

      # nginx(8080) => node(23001)
      #    str += "#EXTINF:,N8080#{ret.artist} - #{title}\n"
      #    str += "http://#{request.host}:8080/stream/musicdb/#{ret.id}/file.#{ret.ext}\n"
      
      # node(23001)
      #    str += "#EXTINF:,N23001#{ret.artist} - #{title}\n"
      #    str += "http://#{request.host}:23001/stream/musicdb/#{ret.id}/file.#{ret.ext}\n"

      
      #     str += "http://#{request.host}:#{request.port}/stream/musicdb/#{ret.id}/file.#{ret.ext}?#{rand(Time.new.to_i)}\n"
      #        str += "http://#{request.host}#{ret.path.gsub("/var/smb/sdb1","/resource")}"
      str
    end

    def get_lyric(title,artist)
      title = title.gsub(/^\d+[\s]/,'')
      agent = get_mechanize({:useproxy => true})    
      ret = ""
      begin
        url = "http://www.metrolyrics.com/search.php?category=ArtistTitle&search=#{title}+#{artist}"
        agent.get url
        
        if agent.page.search("#search-results a span.title")[0].child.text == artist
          url = agent.page.search("#search-results a").
            map{|e| "http://www.metrolyrics.com#{e["href"]}"}.first
          if !url.nil?
            agent.get url
            ret = "#{agent.page.search("#lyrics-body p").css('span,br').to_html.gsub('</span>','</span><br/>')}<div style='float:right;'>scraped from <a href='http://www.metrolyrics.com' target='_blank'>www.metrolyrics.com</a></div>"
          end
        end
      rescue
      end
      
      if ret == ""
        begin    
          url = "http://www.kasi-time.com/search.php?keyword=#{title}&cat_index=song"
          agent.get url
          a_link = nil
          agent.page.search(".content tr").slice(2,100).each do |tr|
            if tr.css("a")[0].child.text == title && tr.css("a")[1].child.text == artist
              tr.css("a")[0]["href"] =~/item-(\d+)\.html/
              a_link = $1
              break
            end
          end
          
          if !a_link.nil?
            agent.get "http://www.kasi-time.com/item_js.php?no=#{a_link}"
            ret = "#{agent.page.body.toutf8.
        gsub("document.write('",'').
        gsub("');",'').
        gsub('\\','')}<br/><div style='float:right;'>scraped from <a href='http://www.kasi-time.com' target='_blank'>www.kasi-time.com</a></div>"
          end
        rescue
        end
        
      end
      return ret
    end

    def get_bio2(artist)
      begin
        nokogiri,nokogirija = get_last_fm_artist_nokogiri(artist)
        found = false
        name = "<h1>#{nokogiri.xpath('//artist/name').first.text}</h1>"
        img1 = nokogiri.xpath('//artist/image[@size="mega"]').first.text
        img2 = nokogirija.xpath('//artist/image[@size="mega"]').first.text
        #"<img src=#{nokogiri.xpath('//artist/image[@size="mega"]').first.text} alt=#{artist} /><br/>"        
        imgsrc = img1 > img2 ? img1 : img2
        found = true if imgsrc.size > 3
        img = "<img src=#{imgsrc} /><br/>"        
        if nokogirija.xpath('//bio/content').first.text.to_s.length > 40
          wiki = "<p>#{nokogirija.xpath('//bio/content').first.text}</p>"
        else
          wiki = "<p>#{nokogiri.xpath('//bio/content').first.text}</p>"
        end
        
        footer = "<div style='float:right'>from last.fm api</div>"
        return "" unless found
        return name + img + wiki + footer
      rescue
        return ""
      end
    end

    def get_wikipedia(artist)
      agent = get_mechanize({:useproxy => true})    
      ret = ""
      
      begin
        url = "http://ja.wikipedia.org/wiki/#{URI.escape(artist)}"
        agent.user_agent_alias = 'Windows IE 7'
        agent.get url
        ret += "<a href='#{url}' target='_blank'>" + agent.page.search("#firstHeading").to_s
        ret += agent.page.search("#bodyContent p").to_s.gsub(/<a .*?>/,'').gsub(/<\/a>/,'')
        ret += "</a><br/><div style='float:right;'>scraped from <a href='http://ja.wikipedia.org/' target='_blank'>ja.wikipedia.org</a></div>"
      rescue
      end
      
      begin 
        if ret == ""
          url = "http://wikipedia.org/wiki/#{URI.escape(artist)}"
          agent.user_agent_alias = 'Windows IE 7'
          agent.get url
          ret = ""
          ret += "<a href='#{url}' target='_blank'>" + agent.page.search("#firstHeading").to_s
          ret += agent.page.search("#bodyContent p").to_s.gsub(/<a .*?>/,'').gsub(/<\/a>/,'')
          ret += "</a><br/><div style='float:right;'>scraped from <a href='http://wikipedia.org/' target='_blank'>wikipedia.org</a></div>"
        end
      rescue
      end
      return ret
    end

    
  end

  ### page ####################
  get "#{get_prefix}/" do #,:cache => true do
    ua = request.user_agent
    if ["Android","iPhone"].find{|s| ua.include?(s)}
      redirect to( "#{get_prefix}/smartphone")
    end

    protected!
    @config = "sinatra"
    @prefix = get_prefix
    expires 36000
    cache_control :public, 36000
    erb :index
  end

  get "#{get_prefix}/ip" do #,:cache => false do
#     "cached?"
     ip = env["X_Forwarded_For"] || env["Http_X_Forwarded_For"] || env["X_FORWARDED_FOR"] ||env["HTTP_X_FORWARDED_FOR"] || request.ip
     ip
  end

  get "#{get_prefix}/file/:mediaid" do #,:cache=> true do
    protected!
#    @mediaurl ="http://#{request.host}:#{request.port}#{get_prefix}/api/stream/#{params[:mediaid]}/file.mp3"
#    @mediaurl ="http://#{request.host}:#{request.port}#{get_prefix}/api/stream2/#{params[:mediaid]}/file.mp3"

    ## node version
    @media = Musicmodel.find(params[:mediaid])
    @mediaurl ="/stream/musicdb/#{params[:mediaid]}/file.#{@media.ext}"


    @prefix = get_prefix
    cache_control :public, :max_age => 60* 60 * 12
    expires 60 * 60 * 24#,:public
    erb :swf
  end

  get "#{get_prefix}/files/:midskey" do #,:cache => true do
    protected!
    expires 36000
    cache_control :public, 36000
    id = params[:midskey]
    mids = nil
    @mret = [].to_json
    begin
      mids = Mid.find(id)
      @mret = Musicmodel.where(:_id.in => mids.mids ).only(:_id,:title,:album,:genre,:artist,:tag,:path,:ext).to_a.to_json
    rescue => ex
    end
    @prefix = get_prefix
    erb :files
  end

  get "#{get_prefix}/stored" do
    protected!
    cache_control :public, :max_age => 0
    expires 0
    @config = "sinatra"
    @result = Stored.all.desc(:created_at)
    @prefix = get_prefix
    erb :stored
  end

  # no sinatra cache to reflash with -X purge directly.
  get "#{get_prefix}/statistics" do
#    cache_control :public, :max_age => 3600 * 24 * 2
#    expires 3600 * 24 * 2 ,:public
    @config = "sinatra"
    @result = Statistics.count
    @prefix = get_prefix
    erb :statistics
  end

  get "#{get_prefix}/welcome" do #,:cache => true do
    expires 36000000
    cache_control :public, 3600000
    @config = "sinatra"
    @prefix = get_prefix
    erb :welcome
  end

  get "#{get_prefix}/smartphone" do
    protected!
    @config = "sinatra"
    @prefix = get_prefix
    erb :smartphone
  end
  
  ##########  manage  ###########################################
  get "#{get_prefix}/manage" do
    protected!
    @prefix = get_prefix
    ret = ["<h1>manage page</h1>"]
    place_folder = "<li><a href='#href#' target='_blank'>#link#</a>"
    ret << place_folder.gsub("#href#","/musicdb_dev/manage/update_db").gsub("#link#",'update_db')
  end

  get "#{get_prefix}/manage/update_db" do
    protected!
    @prefix = get_prefix
    ret = ["<h1>DONE:musicdb/manage/updatet_db</h1>"]
    ret = (ret + Musicmodel.update_db).flatten
    ret.join("<li>")
  end

  ##########  /manage  ###########################################

  ### API #####################

  get "#{get_prefix}/api/genres" do
    #  rets = Genremodel.all.only(:id,:name,:models_count).desc(:name)
    rets = cache( "genres", :expires_in => 0 ) do
      Genremodel.all.only(:id,:name,:models_count).asc(:name)
    end
    expires 0
    cache_control :public, 0
    content_type  'application/json; charset=utf-8'
    if rets.nil?
      [{:status => "ng",:total => 0,:next => 'no'},[{}]].to_json
    else
      ret = []
      rets.each do |e|
        elem = {}
        elem[:id] = e.id;
        elem[:name]  = "#{e.name}"
        elem[:num] = e.models_count
        elem[:name2] = "#{e.name}(#{elem[:num]})"
        ret << elem
      end
      [{:status => "ok",:next => 'no',:total => rets.size },ret].to_json
    end
  end

  ### static #############
  get "#{get_prefix}/scripts/application.js" do #,:cache => true do
    @prefix = get_prefix
    etime = 0
    expires etime
    cache_control :public, etime

    content_type 'application/javascript'  
    erb :'scripts/application' 
  end

  get "#{get_prefix}/scripts/swf.js" do #,:cache => true do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'application/javascript'
    erb :'scripts/swf'
  end

  get "#{get_prefix}/scripts/jsfiles.js" do #,:cache => true do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'application/javascript'
    erb :'scripts/jsfiles'
  end

  get "#{get_prefix}/scripts/jquery.prettyphoto.js" do # ,:cache => true do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type  'application/javascript'
    erb :'scripts/jquery.prettyphoto'
  end

  get "#{get_prefix}/css/pc.css" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'text/css'
    erb :'css/pc'
  end

  get "#{get_prefix}/css/swf.css" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'text/css'
    erb :'css/swf'
  end

  get "#{get_prefix}/css/prettyPhoto.css" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'text/css'
    erb :'css/prettyPhoto'
  end

  get "#{get_prefix}/css/jquery.mobile.css" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'text/css'
    erb :'css/jquery.mobile'
  end

  get "#{get_prefix}/css/smartphone.css" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type 'text/css'
    erb :'css/smartphone'
  end

  get "#{get_prefix}/js/jquery.js" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type  'application/javascript'
    erb :'js/jquery'
  end

  get "#{get_prefix}/js/jquery.mobile.js" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type  'application/javascript'
    erb :'js/jquery.mobile'
  end

  get "#{get_prefix}/js/smartphone.js" do
    @prefix = get_prefix
    expires 0
    cache_control :public, 0
    content_type  'application/javascript'
    erb :'js/smartphone'
  end

  get "#{get_prefix}/css/images/:path" do 
    filepath = File.dirname(__FILE__) + "/views/css/images/" + params[:path]
    send_file filepath
  end

  ### API #####################
  get "#{get_prefix}/api/search" do
    cache_control :public, :max_age => 1
    expires 1
    page = params[:p] ||= 1
    page = page.to_i
    per  = params[:per] ||= 10
    per = per.to_i
    content_type  'application/json; charset=utf-8'

    require 'kconv'
    qs = params[:qs].toutf8

    if qs == 'recent'
      recent(qs).to_json
    else
      ret =   Musicmodel.search(qs.gsub('<OR>','|'),page,per)
      ret.to_json
    end
  end

  get "#{get_prefix}/api/search_by_genre" do
    cache_control :public, :max_age => 0
    expires 0
    page = params[:p] ||= 1
    page = page.to_i
    per  = params[:per] ||= 10
    per = per.to_i

    rets = cache( "search_by_genre_#{params[:qs]}_#{params[:p]}_#{params[:per]}", :expires_in => 3600000 ) do
      Musicmodel.search_by_genre(params[:qs].gsub('<OR>','|'),page,per)
    end
    content_type  'application/json; charset=utf-8'
    rets.to_json
  end

  post "#{get_prefix}/api/gzip" do
    protected!
    begin
      require "tmpdir"
      ids = params[:qs].split(' ')
      rets = Musicmodel.where(:_id.in => ids)

      path = nil
      tmp = Tempfile.open(["music_pack_",'.tar.gz'],'/tmp') do |io|
        path = io.path
      end
      dirname = nil
      Dir.mktmpdir do |dir|
        seri = 0
        rets.each do |music|
          request.logger.info music.path
          # musicのpathに実際の格納場所がセットされている。
          filename = "p#{seri}_#{File.basename(music.path)}"
          seri = seri + 1
          FileUtils.cp(music.path, "#{dir}/#{filename}")
        end
        system "tar -czf #{path} #{dir}"
     end
     content_type 'application/gzip'
     send_file path ,:filename => 'musicdb_pack.tar.gz'
     FileUtils.rm(path)
    rescue => ex
      request.logger.fatal ex.to_s
    end
  end

  post "#{get_prefix}/api/tar" do
    protected!

    begin
      require "tmpdir"
      ids = params[:qs].split(' ')
      rets = Musicmodel.where(:_id.in => ids)

      path = nil
      tmp = Tempfile.open(["music_pack_",'.tar'],'/tmp') do |io|
        path = io.path
      end
      dirname = nil
      Dir.mktmpdir do |dir|
        seri = 0
        rets.each do |music|
          request.logger.info music.path
          # musicのpathに実際の格納場所がセットされている。
          filename = "p#{seri}_#{File.basename(music.path)}"
          seri = seri + 1
          FileUtils.cp(music.path, "#{dir}/#{filename}")
        end
        system "tar -cf #{path} #{dir}"
     end
     content_type 'application/tar'
     send_file path ,:filename => 'musicdb_pack.tar'
     FileUtils.rm(path)
    rescue => ex
      request.logger.fatal ex.to_s
    end
  end

  post "#{get_prefix}/api/m3u" do

    begin
      require 'digest'
      ids = params[:qs].split(' ')
      puts ids
      buf = []
      rets = cache( "m3u_#{Digest::MD5.hexdigest params[:qs]}", :expires_in => 3600000 ) do
        Musicmodel.where(:_id.in => ids)
      end
      rets.each do |music|
        buf << make_m3u_elem(music)
      end
      path = get_tmpfile do
        buf.join('')
      end
      send_file path ,:type => 'audio/x-mpegurl'
    rescue => ex
      [{:status => "ng",:ex => ex.to_s},[{}]].to_json
    end
  end

  get "#{get_prefix}/api/statistics" do
    begin
      Statistics.new(:name => params[:name],:kind => "web",:music_id => params[:mid].to_s).save
    rescue
    end
    content_type  'application/json; charset=utf-8'
    {:status => "ok" ,:msg => "Thank you."}.to_json
  end

  get "#{get_prefix}/api/stream2/:mid/*"  do
    ok_ip?

    music = Musicmodel.find(params[:mid])
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12 ,:public

    if music.nil?
      send_file "/var/smb/sdb1/music/iTunes1/ASIAN KUNG-FU GENERATION/Fanclub/02 World Apart.mp3" ,:type => 'audio/mp3'
    else
      type = File.extname(music.path).gsub('.','')
      if type == 'm4a'
        type = 'mp4'
      elsif type == 'mp3'
        type = 'mpeg'
      end
      puts music.path.gsub("/var/smb/sdb1","/resource")
      #    x_send_file music.path.gsub("/var/smb/sdb1","/resource")
      x_send_file music.path ,:type => "audio/#{type}"
      #send_file music.path ,:type => "audio/#{type}"
    end
  end

  get "#{get_prefix}/api/stream/:mid/*" do
    # ok_ip?
    music = Musicmodel.find(params[:mid])
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12

    if music.nil?
      send_file "/var/smb/sdb1/music/iTunes1/ASIAN KUNG-FU GENERATION/Fanclub/02 World Apart.mp3" ,:type => 'audio/mp3'
    else
      begin
        Statistics.new(
                       :name => "M3U:" + music.title + " - " + music.artist + " - " + music.title ,
                       :kind => "m3u",
                       :music_id => music._id
                       ).save
      rescue
      end
      type = File.extname(music.path).gsub('.','')
      if type == 'm4a'
        type = 'mp4'
      elsif type == 'mp3'
        type = 'mpeg'
      end
#      x_send_file music.path ,:type => "audio/#{type}"
      send_file music.path ,:type => "audio/#{type}"
      #x_send_file music.path.gsub("/var/smb/sdb1","/resource")
    end
  end

  get "/stream/musicdb/:mid/*" do
    ok_ip?

    music = Musicmodel.find(params[:mid])
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12

    if music.nil?
      send_file "/var/smb/sdb1/music/iTunes1/ASIAN KUNG-FU GENERATION/Fanclub/02 World Apart.mp3" ,:type => 'audio/mp3'
    else
      begin
        Statistics.new(
                       :name => "M3U:" + music.title + " - " + music.artist + " - " + music.title ,
                       :kind => "m3u",
                       :music_id => music._id
                       ).save
      rescue
      end
      type = File.extname(music.path).gsub('.','')
      if type == 'm4a'
        type = 'mp4'
      elsif type == 'mp3'
        type = 'mpeg'
      end
#      x_send_file music.path ,:type => "audio/#{type}"
      send_file music.path ,:type => "audio/#{type}"
      #x_send_file music.path.gsub("/var/smb/sdb1","/resource")
    end

  end

  get "#{get_prefix}/api/backjpg" do
    cache_control :public, :max_age => 180;
    expires 180
    @files = Dir.glob(File.dirname(__FILE__) + "/public/back/*.jpg")  
    seed = rand(@files.size).to_i
    path = @files[seed]
    send_file path
  end

  post "#{get_prefix}/api/files/set_mids" do
    content_type  'application/json; charset=utf-8'
    mids = Mid.new(:mids => params[:mids].split(' '))
    mids.save
    #  session['midskey'] = mids.id
    {:midskey => mids.id,:mids => mids.mids}.to_json
  end

  post "#{get_prefix}/api/files/set_store" do
    content_type  'application/json; charset=utf-8'
    id = params[:midskey]
    mids = nil
    mret = [].to_json
    begin
      mids = Mid.find(id)
      mt = Musicmodel.where(:_id.in => mids.mids ).only(:_id,:title,:album,:genre,:artist,:tag,:path,:ext).to_a.map {|e|"#{e.genre}-#{e.artist}-#{e.album}-#{e.title}" }
      stored = Stored.new(:midsid => mids._id.to_s,:titles => mt,:created_at => Time.new)
      stored.save
      {:status => "ok" , :msg => "stored." ,:storedid => stored._id}.to_json
    rescue => ex
      puts ex
      {:status => "ng" , :msg => "not stored." }.to_json
    end
  end

  get "#{get_prefix}/api/files/set_store/delete/:id" do
    content_type  'application/json; charset=utf-8'
    begin
      stored = Stored.find(params[:id])
      stored.delete
      {:status => "ok" , :msg => "deleted."}.to_json
    rescue => ex
      puts ex
      {:status => "ng" , :msg => "not deleted." }.to_json
    end
  end

  get "#{get_prefix}/api/files/generate_midskey_from" do
    content_type  'application/json; charset=utf-8'
    begin
      cou = Musicmodel.where(:artist => params[:artist]).count
      seed = rand(cou) 
      l = 20
      if seed + l >= cou
        seed = cou - l
      end
      seed = 0 if  seed < 0
      mids = Musicmodel.where(:artist => params[:artist]).only(:id).skip(seed).limit(l).to_a.map{|e| e.id}
      if(mids.size > 0)
        mids = Mid.new(:mids => mids)
        mids.save
        {:status=>"ok",:midskey => mids.id,:mids => mids.mids}.to_json
      else
        {:status=>"ng",:message => "no entry #{seed} #{cou} "}.to_json
      end
    rescue => ex
      {:status=>"ng" ,:message => ex.to_s}.to_json
    end
  end

  get "#{get_prefix}/api/files/get_mids" do
    content_type  'application/json; charset=utf-8'
    mids = nil
    begin
      mids = Mids.find(id)
    rescue => ex
      halt {}.to_json
    end
    ret = mids.mids.to_json
    mids.delete
    ret
  end

  ### API SCRAPTE #####################
  get "#{get_prefix}/api/scrape/amazon" do 
    content_type  'application/json; charset=utf-8'
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12

    agent = Mechanize.new
    artist = params[:artist].gsub(/^\s*\d+\s*/,'')
    album = params[:album].gsub(/^\s*\d+\s*/,'')
    url = "http://www.amazon.co.jp/s/ref=nb_sb_noss?__mk_ja_JP=%83J%83%5E%83J%83i&url=search-alias%3Dpopular&field-keywords=#{URI.escape artist.to_s.tosjis}+#{URI.escape album.to_s.tosjis}&x=0&y=0"
    imgpath = "/musicdb/cd.gif"
    status = "ng"
    begin
      agent.get url
      imgpath = agent.page.search("div#Results img").map{|e| e["src"]}.select{|e| e=~/http\:\/\/ecx/}.first.gsub(/\_.+_\.jpg/,'.jpg')
      status = "ok"
    rescue
    end
    {:status => status,:src => imgpath,:url => url}.to_json
  end

  get "#{get_prefix}/api/scrape/lyric" do 
    content_type  'application/json; charset=utf-8'
    cache_control :public, :max_age => 60* 60 * 120
    expires 60* 60 * 120
    rylic = get_lyric(params[:title],params[:artist])
    {:html => rylic}.to_json
  end

  get "#{get_prefix}/api/scrape/bio" do
    content_type  'application/json; charset=utf-8'
    rylic = get_bio2(params[:artist])
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12
    {:html => rylic,:status => rylic == "" ? :ng : :ok}.to_json
  end

  get "#{get_prefix}/api/scrape/wikipedia" do
    content_type  'application/json; charset=utf-8'
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12
    rylic = get_wikipedia(params[:artist])
    {:html => rylic,:status => rylic == "" ? :ng : :ok}.to_json
  end

  get "#{get_prefix}/api/scrape/similar" do 
    content_type  'application/json; charset=utf-8'
    cache_control :public, :max_age => 60* 60 * 12
    expires 60* 60 * 12
    rylic = get_similar_artist_in_mongo({:artist => params[:artist] })
    {:json => rylic,:status => rylic == [] ? :ng : :ok}.to_json
  end

  ### age #####################
  get "#{get_prefix}/test/02mp3" do
    send_file "/var/smb/sdb1/music/iTunesMac/Vocaloid/impacts/02.mp3"
  end

  get "#{get_prefix}/test/01mp3" do
    #  x_send_file "/var/www/resource/music/iTunesLossless/mp3/新谷良子 -/03. crossingdays (OFF VOCAL).mp3"
    x_send_file "/resource/music/iTunesLossless/mp3/新谷良子 -/03. crossingdays (OFF VOCAL).mp3"
  end

  get "#{get_prefix}/:file" do
    cache_control :public, :max_age => 60* 60 * 12
    expires 60 * 60 * 24
    send_file File.dirname(__FILE__) + "/public/"  + params[:file]
  end

  get "#{get_prefix}/images/prettyPhoto/light_rounded/:file" do 
    cache_control :public, :max_age => 60* 60 * 12
    expires 60 * 60 * 24
    send_file File.dirname(__FILE__) + "/public/images/prettyPhoto/light_rounded/"  + params[:file]
  end

  get "#{get_prefix}/images/prettyPhoto/default/:file" do 
    cache_control :public, :max_age => 60* 60 * 12
    expires 60 * 60 * 24
    send_file File.dirname(__FILE__) + "/public/images/prettyPhoto/default/"  + params[:file]
  end

  get "#{get_prefix}/images/:file" do
    cache_control :public, :max_age => 60* 60 * 12
    expires 60 * 60 * 24
    send_file File.dirname(__FILE__) + "/public/images/"  + params[:file]
  end
end
