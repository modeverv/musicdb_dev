#! /bin/bash
cd /var/www/ruby/musicdb_dev/
bundle exec unicorn -c /var/www/ruby/musicdb_dev/unicorn_p.conf --env production -D
echo "waiting..."
sleep 5
ps ax|grep unicorn

