// for diffs shown in the PBDiffWindow

var setMessage = function(message) {
	$("message").style.display = "";
	$("message").innerHTML = message.escapeHTML();
	$("diff").style.display = "none";
}

var showDiff = function(diff) {
	highlightDiff(diff, $("diff"));
}

var showFile = function(txt) {
	showDiff(txt);
	return;
}
