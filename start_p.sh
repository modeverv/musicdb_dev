#! /bin/bash
export PATH=/home/seijiro/.rbenv/bin:$PATH
echo $PATH
eval "$(rbenv init -)"
cd /var/www/ruby/musicdb_dev/
which ruby
bundle exec unicorn -c /var/www/ruby/musicdb_dev/unicorn_p.conf --env production -D
# echo "waiting..."
# sleep 5
# ps ax|grep unicorn

