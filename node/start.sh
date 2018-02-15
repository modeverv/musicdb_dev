#! /bin/bash

source ~/.nvm/nvm.sh
nvm use 0.8.4
which node

FOREVER_BIN=/home/seijiro/sinatra/musicdb_dev/node/node_modules/forever/bin/forever
#LOGFILE=/home/seijiro/sinatra/musicdb_dev/tmp/log/node_`date +%Y%M%d%H%M%S`.log
#LOGFILE0=/home/seijiro/sinatra/musicdb_dev/tmp/log/node_a_`date +%Y%M%d%H%M%S`.log
#LOGFILE1=/home/seijiro/sinatra/musicdb_dev/tmp/log/node_e_`date +%Y%M%d%H%M%S`.log
#PID=/home/seijiro/sinatra/musicdb_dev/tmp/pids/musicnode_`date +%Y%M%d%H%M%S`.pid

LOGFILE=/home/seijiro/sinatra/musicdb_dev/tmp/log/node.log
LOGFILE0=/home/seijiro/sinatra/musicdb_dev/tmp/log/node0.log
LOGFILE1=/home/seijiro/sinatra/musicdb_dev/tmp/log/node1.log
PID=/home/seijiro/sinatra/musicdb_dev/tmp/pids/music_node.pid

#$FOLEVER_BIN start -l $LOGFILE -o $LOGFILE0 -e $LOGFILE1 --pidfile $PID web.js
node $FOREVER_BIN start -a -l $LOGFILE -o $LOGFILE0 -e $LOGFILE1 --pidfile $PID web.js
