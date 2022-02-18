var loadQuery = function(query){
	$("#loader").css('visibility', 'visible');
	$("#results > tbody").html("<tr></tr>");
	$("#searchform").val("");
	
	var phid = 13692155;
	var rows = 0;
	var done = 0;
	var loop = function(id, max, row){
		if(rows<row){
			$('#results tr:last').after('<tr><td class="minpath" id="min'+row
			                            +'"></td><td class="maxpath" id="max'+row+'"></td></tr>');
			$('#results tr:last').after('<tr><td class="minpath linksto sans" id="minl'+row
                            +'"></td><td class="maxpath linksto sans" id="maxl'+row+'"></td></tr>');
			rows++;
		}
		$.get( '/search',{q:id, max:max}, function(res) {
			if(row > 1){
				$((max?"#maxl":"#minl")+(row-1)).html("links to").hide().fadeIn();
			}
			$((max?"#max":"#min")+row).html
				('<a target="_blank" href="https://en.wikipedia.org/wiki/'+res.title+'">'+res.title+'</a>').hide().fadeIn();
			if(res.prev) loop(res.prev, max, row + 1);
			else{
				done++;
				if(done==2) $("#loader").fadeOut();
			}
		});
	}
	$.get( '/search',{q:query, max:true, byTitle:true}, function(res) {
		if(res.missing){
			query = query.split("+").join(" ");
			$("#error").html("Couldn't find "+query+". Sorry :c<br>Capitalizing the title correctly might help.");
			$("#loader").fadeOut();
		} else{
			$("#results").css('visibility', 'visible');
			loop(res.id, true, 1);
			loop(res.id, false, 1);
		}
	});
}

$(document).ready(function() {
	$("#random").click(function(){
		$.get( '/random', {}, function(res) {
			var json = JSON.parse(res);
			window.location.href = "/?q="+json.title;
		});
		//window.location.href = "http://example.com/new_url";
	});

	var query = $.url('?q');
	if(query) loadQuery(query);
	else if($.url('?')==="random") $.get( '/random', {}, function(res) {
		var json = JSON.parse(res);
		document.title = json.title + " to Philosophy";
		loadQuery(json.title);
	});
});