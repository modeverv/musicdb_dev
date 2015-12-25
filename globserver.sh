#!/usr/bin/env bash

cd /home/seijiro/sinatra/musicdb_dev/

#source /home/seijiro/.rvm/environments/ruby-1.9.3-p392
echo `which ruby`
echo `ruby -v`
echo `rvm gemset list`
ruby /home/seijiro/sinatra/musicdb_dev/glob_server.rb
