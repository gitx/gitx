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

// TODO: need to be refactoring
var openFileMerge = function(file,sha,sha2) {
	alert(file);
	alert(sha);
	alert(sha2);
	Controller.openFileMerge_sha_sha2_(file,sha,sha2);
}
