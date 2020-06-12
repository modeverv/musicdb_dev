#!/usr/bin/env bash

cd /var/www/ruby/musicdb_dev/
source /home/seijiro/.profile
export PATH="/home/seijiro/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
export PATH=/usr/lib/x86_64-linux-gnu:/home/seijiro/.rbenv/shims:/home/seijiro/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin


#source /home/seijiro/.rvm/environments/ruby-1.9.3-p392
#source /home/seijiro/.rvm/environments/ruby-1.9.3-p551

echo `which ruby`
echo `ruby -v`
#echo `rvm gemset list`
bundle exec ruby /var/www/ruby/musicdb_dev/glob_server.rb
