#! /bin/bash
PID=`cat tmp/pids/puma.pid`
echo $PID
ps ax|grep puma
kill -USR2 $PID
echo "waiting..."
sleep 10
kill -QUIT $PID
echo "waiting..."
sleep 5
ps ax|grep puma
echo "ok?"