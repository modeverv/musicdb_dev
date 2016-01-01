// exec NODE_ENV="production" node web.js >> ../log/node.log 2>&1
var express = require('express');
var mongoose = require('mongoose');

var app = express.createServer();


//var musicdb = mongoose.createConnection('mongodb://192.168.110.7/misic-mongoid');
//var mediadb2 = mongoose.createConnection('mongodb://192.168.110.7/media-mongoid4');
var musicdb = mongoose.createConnection('mongodb://localhost/misic-mongoid');
var mediadb2 = mongoose.createConnection('mongodb://localhost/mediadb2-mongoid');

var MusicmodelSchema = new mongoose.Schema({
     _id : mongoose.Schema.ObjectId
    ,path : String
});
var MediamodelSchema = new mongoose.Schema({
     _id : mongoose.Schema.ObjectId
    ,path : String
});

var Musicmodel = musicdb.model('Musicmodel',MusicmodelSchema) ;
var Mediamodel = mediadb2.model('Mediamodel',MediamodelSchema) ;


app.get('/', function(req, res) {
    res.send('Express Mongoose Media Stream Server.');
});

app.get("/musicdb/:mid/:param",function(req,res){
  Musicmodel.findById(req.params.mid,function(err,doc){
     if(doc)
       res.sendfile(doc.path,function(ferr){
            if(ferr)
//              next(ferr);
              console.log("error %s",doc.path);
            else
              console.log("transfered %s",doc.path);
       });
     else
       res.send("no file error ");
  });
});

app.get("/mediadb2/:mid/:param",function(req,res){
  Mediamodel.findById(req.params.mid,function(err,doc){
     if(doc)
       res.sendfile(doc.path,function(ferr){
            if(ferr)
//              next(ferr);
              console.log("error %s",doc.path);
            else
              console.log("transfered %s",doc.path);
       });
     else
       res.send("no file error ");
  });
});

app.get("/stream/02.mp3",function(req,res){
    res.sendfile("/var/www/resource/music/iTunesMac/Vocaloid/impacts/02.mp3");
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
    var lines = ["192|124\.110\.137"]; 
    var reg = new RegExp(lines[0]);
    if (reg.test(ip_address)){
  	  console.log("ip is local.ok!");
	  ok_flg = true;
    }
    ok_flg = true;
    if (!ok_flg) { res.send(ip_address + " is not permitted."); return; }
//  else {res.send("ok ip address!");return;}

    Musicmodel.findById(req.params.mid,function(err,doc){
      if(doc){
       console.log("path is %s",doc.path);  
       res.sendfile(doc.path,function(ferr){
            if(ferr)
//              next(ferr);
              console.log("error %s",doc.path);
            else
              console.log("transfered %s",doc.path);
       });
     }else
       res.send("no file error.");
  });

});

app.get("/stream/mediadb2/:mid/:param",function(req,res){
  Mediamodel.findById(req.params.mid,function(err,doc){
     if(doc)
       res.sendfile(doc.path,function(ferr){
            if(ferr)
//              next(ferr);
              console.log("error %s",doc.path);
            else
              console.log("transfered %s",doc.path);
       });
     else
       res.send("no file error ");
  });
});


var port = process.env.PORT || 23001;
app.listen(port, function(){
  console.log("Listening on " + port);
});

