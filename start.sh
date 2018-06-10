#! /bin/bash
unicorn -c /var/www/ruby/musicdb_dev/unicorns.conf --env production -D
echo "waiting..."
sleep 5
ps ax|grep unicorn

