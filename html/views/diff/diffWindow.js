var setMessage = function(message) {
	$("message").style.display = "";
	$("message").innerHTML = message.escapeHTML();
	$("diff").style.display = "none";
}

var showFile = function(txt) {
	$("diff").style.display = "";
	$("diff").innerHTML = txt;
	$("message").style.display = "none";
}
