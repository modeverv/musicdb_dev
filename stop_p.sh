#! /bin/bash

PID=`cat /var/www/ruby/musicdb_dev/tmp/pids/unicorn_p.pid`
kill -9 $PID
sleep 5
ps aux|grep unicorn
