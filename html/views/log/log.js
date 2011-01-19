var selectCommit = function(a) {
	window.Controller.selectCommit_(a);
	return false;
}

var setMessage = function(message) {
	$("message").style.display = "";
	$("message").innerHTML = message.escapeHTML();
	$("log").style.display = "none";
}

var showFile = function(txt) {
	$("log").innerHTML = txt;
	$("log").style.display = "";
	$("message").style.display = "none";
}
