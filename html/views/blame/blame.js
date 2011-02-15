var setMessage = function(message) {
	$("message").style.display = "";
	$("message").innerHTML = message.escapeHTML();
	$("blame").style.display = "none";
}

var showFile = function(txt) {
	$("blame").style.display = "";
	$("blame").innerHTML="<pre>"+txt+"</pre>";
	$("message").style.display = "none";
	
	SyntaxHighlighter.defaults['toolbar'] = false;
	SyntaxHighlighter.highlight();
	return;
}

var selectCommit = function(a) {
	Controller.selectCommit_(a);
}
