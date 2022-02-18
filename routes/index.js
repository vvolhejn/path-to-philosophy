var wikiApi = require("wikiapi"); //"../node_modules/wiki-api/wiki-api"
var RANDOM_BUFFER = 10;

exports.blankQuery = function(req, res){
	res.render('index', {
		query: '',
		minPath: [],
		maxPath: [],
		found: false
	});
};

var phid = "13692155";

var convert = function(from, fromTitle, client, cb){
	var prefix = fromTitle?"name:id:":"id:name:";
	client.get(prefix + from, function(err, reply) {
		if(!reply){
			console.log("Asking wiki for "+(fromTitle?"ID":"title")+":\t"+from);
			var fn = fromTitle?wikiApi.getId:wikiApi.getTitle;
			fn(from, function(to){
				if(to) client.set(prefix + from, to);
				cb(to);
			});
		} else {
			cb(reply);
		}
	});
}

var getTitle = function(id, client, cb){
	convert(id, false, client, cb);
};

var getId = function(title, client, cb){
	convert(title, true, client, cb);
};

var getPrev = function(query, max, client, cb){ //bere a vraci id
	if(!query){
		cb();
		return;
	}
	if(query === phid) cb();
	else client.get("id:prev" + (max?"max:":"min:")
	                + query, function(err, reply) {
	                	if(!reply){
	                		cb();
	                	} else {
	                		cb(reply);
	                	}
	                });
}

var getPath = function(query, max, client, cb){ //bere a vraci id
	if(!query){
		cb([]);
		return;
	}
	if(query === phid) cb(["Philosophy"]);
	else client.get("id:prev" + (max?"max:":"min:")
	                + query, function(err, reply) {
	                	if(!reply){
	                		cb([]);
	                	} else {
	                		getPath(reply, max, client, function(res){
	                			getTitle(query, client, function(name){
	                				res.push(name);
	                				cb(res);
	                			});
	                		})
	                	}
	                });
}

var normalizeTitle = function(title){
	if(!title || title.length==0) return "";
	title = title.split("_").join(" "); //replaceall
	title = title.substring(0,1).toUpperCase() + title.substring(1);
	return title;
}

exports.submit = function(client){ //redisovy klient
	return function(req, res, next){
		var query = normalizeTitle(req.body.myquery) || req.query.q;
		if(!query) exports.blankQuery(req, res);
		else {
			getId(query, client, function(id){
				if(id==-1){
					res.render('index', {
						query:query,
						minPath:[],
						maxPath:[],
						found:false});
					return;
				}
				//getTitle se vola naprazdno, aby se pripadne wikiapi neptalo dvakrat - pro dve cesty
				getTitle(id, client, function(){
					var minPath, maxPath;
					var done = 0;
					var attempt = function(){ //načítá dvě cesty zároveň a není jasné, která bude dřív.
						done++;
						if(done===2){
							res.render('index', {
								query:query,
								minPath:minPath,
								maxPath:maxPath,
								found:(minPath.length>0)});
						}
					}
					getPath(id, true, client, function(path){
						path.reverse();
						maxPath = path;
						attempt();
					});
					getPath(id, false, client, function(path){
						path.reverse();
						minPath = path;
						attempt();
					});
				})
			});
		}
	};
};

exports.directQuery = function(client){
	return function(req, res){
		res.render('index', {
			query: normalizeTitle(req.query.q)
		});
	}
	//return exports.submit(client);
}

exports.search = function(client){
	var byId = function(req, res, id){
		if(id==-1 || isNaN(id)) res.send({missing:true});
		else getTitle(id, client, function(title){
			if(!title) res.send({missing:true});
			else getPrev(id, ((req.query.max==="true")?true:false), client, function(prev){
				res.send({id:id, title:title, prev:prev});
			});
		});
	};
	return function(req, res){
		if(req.query.byTitle){
			getId(normalizeTitle(req.query.q), client, function(id){
				byId(req, res, id);
			});
		} else byId(req, res, req.query.q);
	}
}


exports.random = function(client){
	return function(req, res){
		client.lpop("random", function(err, reply){
			res.send(reply);
			client.llen("random", function(err, reply){
				if(reply < RANDOM_BUFFER) {
					wikiApi.random(function(arr){
						arr.forEach(function(cur){
							client.rpush("random", JSON.stringify(cur));
							client.set("name:id:"+cur.title, cur.id, function(err, reply){if(err)console.log("Redis err:"+err);});
							client.set("id:name:"+cur.id, cur.title, function(err, reply){if(err)console.log("Redis err:"+err);});
						});
					});
				}
			});
		});
	}
}