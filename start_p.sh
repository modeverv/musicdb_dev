#! /bin/bash
cd /home/seijiro/sinatra/musicdb_dev/
bundle exec unicorn -c /home/seijiro/sinatra/musicdb_dev/unicorn_p.conf --env production -D
echo "waiting..."
sleep 5
ps ax|grep unicorn

