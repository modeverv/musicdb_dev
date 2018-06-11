#!/usr/bin/env bash

cd /var/www/ruby/musicdb_dev/
source /home/seijiro/.profile

#source /home/seijiro/.rvm/environments/ruby-1.9.3-p392
#source /home/seijiro/.rvm/environments/ruby-1.9.3-p551

echo `which ruby`
echo `ruby -v`
#echo `rvm gemset list`
bundle exec ruby /var/www/ruby/musicdb_dev/glob_server.rb
