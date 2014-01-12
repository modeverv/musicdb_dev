# personal music web
by modeverv

# REQUIREMENTS
MongoDB
sinatra
sinatra-reloader
mechanize
mongoid
MeCab
tablib
ruby-taglib
ruby-taglib2
ruby-mp3info

and web server
# config
modify ok_ip.txt


# install

    bundle install
    
install MeCab.
# start
to start sinatra,configure `unicorn_p.conf` and

    ./start_p.sh

to start node.js file transfer

    ./node/start.sh

# update database by cron
    0 0 *  *   *   nice -n 19 ionice -c 3 /home/seijiro/sinatra/musicdb_dev/globserver.sh > /dev/null 2>&1
    

