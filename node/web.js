// exec NODE_ENV="production" node web.js >> ../log/node.log 2>&1
var express = require('express');
var mongoose = require('mongoose');

//var app = express.createServer();
var app = express();

//var musicdb = mongoose.createConnection('mongodb://192.168.110.7/misic-mongoid');
var musicdb = mongoose.createConnection('mongodb://127.0.0.1/music2-mongoid');

var MusicmodelSchema = new mongoose.Schema({
/*     _id : mongoose.Schema.ObjectId
    ,*/path : String
});


var Musicmodel = musicdb.model('Musicmodel', MusicmodelSchema) ;


app.get("/stream/musicdb/test.mp3",function(req,res){
    console.log("test.mp3");
    console.log( "/var/www/ruby/musicdb_dev/test.mp3");
    res.sendFile("/var/www/ruby/musicdb_dev/test.mp3");
});

app.get("/stream/musicdb/:mid/:param",function(req,res){
    console.log("in /stream/musicdb/%s/%s",req.params.mid,req.params.param);

    // check "remote ip is local"
    var ok_flg = false;
    var ip_address = null;
    try{
        ip_address = req.headers['x-forwarded-for'];
    }
    catch ( error ) {
        ip_address = req.connection.remoteAddress;
    }
    console.log(ip_address);
/*
    var lines = ["192|124\.110\.137"];
    var reg = new RegExp(lines[0]);
    if (reg.test(ip_address)){
  	  console.log("ip is local.ok!");
	  ok_flg = true;
    }
    ok_flg = true;
*/
//    if (!ok_flg) { 
//      res.send(ip_address + " is not permitted."); return;
//     }
//  else {res.send("ok ip address!");return;}
   console.log(req.params.mid);
   var ObjectId = require('mongoose').Types.ObjectId;
   var oId = new ObjectId(req.params.mid);
   console.log(oId);

    Musicmodel.findById(oId, function(err,doc){
     console.log("aaa");
     if(doc){
       console.log("path is %s",doc.path);
       res.sendfile(doc.path,function(ferr){
          if(ferr)
            console.log("error %s",doc.path);
          else
            console.log("transfered %s",doc.path);
       });
     } else {
       res.send("no doc error.");
     }
  });

});

var port = process.env.PORT || 23001;
app.listen(port, '0.0.0.0', function(){
  console.log("Listening on " + port);
});

