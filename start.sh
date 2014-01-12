#! /bin/bash
unicorn -c /var/log/unicorns.conf --env production -D
echo "waiting..."
sleep 5
ps ax|grep unicorn

