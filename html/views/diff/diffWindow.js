// for diffs shown in the PBDiffWindow

var setMessage = function(message) {
	$("message").style.display = "";
	$("message").innerHTML = message.escapeHTML();
	$("diff").style.display = "none";
}

var hideMessage = function() {
	$("message").style.display = "none";
	$("diff").style.display = "";
}

var showDiff = function(diff) {
	hideMessage();
	highlightDiff(diff, $("diff"));
}

var showFile = function(txt) {
	showDiff(txt);
	return;
}
