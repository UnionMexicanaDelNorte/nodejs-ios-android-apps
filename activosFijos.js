var http = require('http');
var url  = require('url');
var sql = require('mssql'); 

 
    
var config = {
    user: 'sa',
    password: '',
    server: 'localhost', 
    database: '',
    options: {
        encrypt: true // Use this if you're on Windows Azure
    }
}
http.createServer(function (req, res) {
  	res.writeHead(200, {'Content-Type': 'text/plain'});
 	var url_parts = url.parse(req.url, true);
    var query = url_parts.query;    
	switch(parseInt(query.accion))
	{
		case 1:
var date = new Date();
var current_hour = date.getHours();

var current_year= date.getFullYear();
var current_month= parseInt( date.getMonth())+1;
if(current_month<10)
{
  current_month="0"+current_month;
}
var current_day= parseInt(date.getDate());
if(current_day<10)
{
  current_day="0"+current_day;
}
var initSalt = '%&/mysalt5=';
var endSalt = 'ThisIsMyEasyToRememberSalt';

var clave = initSalt+current_year+current_month+current_day+endSalt;


var crypto = require('crypto'),
        text = clave,
        key = '7HolaAmigosComoEstan7';

    // create hahs
    var hash = crypto.createHmac('sha512', key);
    hash.update(text);
    var ei = hash.digest('hex');

      if(ei===query.ei)
      {
        sql.connect(config, function(err) {
          console.log(err);
          var request = new sql.Request();
          var querySQL = "SELECT ASSET_CODE,DESCR,START_PERD,LAST_PERD, BASE_GROSS,BASE_DEP,BASE_NET, BASE_PCENT FROM [SUNPLUSADV].[dbo].[CEA_ASSET] WHERE ASSET_CODE =  '"+query.argumento1+"'";
          request.query(querySQL, function(err, recordset) {
             console.log(err);
              res.end(JSON.stringify(recordset));
          });
        });
      }
      else
      {
         res.end("No dijiste la palabra correcta :P");
      }
			
		break;
		default:
		break;
	}	
}).listen(90, '0.0.0.0');
