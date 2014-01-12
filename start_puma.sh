#! /bin/bash
cd /home/seijiro/sinatra/musicdb_dev/
bundle exec puma -C ./puma.conf 
echo "waiting..."
sleep 5
ps ax|grep puma

