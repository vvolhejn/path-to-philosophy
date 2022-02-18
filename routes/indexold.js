var express = require('express');
var router = express.Router();

/* GET home page. */
router.get('/', function(req, res, next) {
  res.render('index', { title: 'Express' });
});

exports.index = function(req, res){
	res.render('photos', {
		title: 'Photos',
		photos: photos
	});
};

exports.form = function(req, res){
	var name = req.body.name || req.query['foo'] ||":(";
		res.render('upload', {
			title: name
		});
	};

exports.submit = function(pathF){ //funkce, ktera vrati cestu z mista, pripadne undefined
	return function(req, res, next){
		var name = req.body.myquery||[":("];
			var path = pathF(name[0]);
			res.render('upload', {title:path});
		};
	};