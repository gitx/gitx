var confirm_gist = function(confirmation_message) {
	if (!Controller.isFeatureEnabled_("confirmGist")) {
		gistie();
		return;
	}
	
	// Set optional confirmation_message
	confirmation_message = confirmation_message || "Yes. Paste this commit.";
	var deleteMessage = Controller.getConfig_("github.token") ? " " : "You might not be able to delete it after posting.<br>";
	var publicMessage = Controller.isFeatureEnabled_("publicGist") ? "<b>public</b>" : "private";
	// Insert the verification links into div#notification_message
	var notification_text = 'This will create a ' + publicMessage + ' paste of your commit to <a href="http://gist.github.com/">http://gist.github.com/</a><br>' +
	deleteMessage +
	'Are you sure you want to continue?<br/><br/>' +
	'<a href="#" onClick="hideNotification();return false;" style="color: red;">No. Cancel.</a> | ' +
	'<a href="#" onClick="gistie();return false;" style="color: green;">' + confirmation_message + '</a>';
	
	notify(notification_text, 0);
	// Hide img#spinner, since it?s visible by default
	$("spinner").style.display = "none";
}

var gistie = function() {
	notify("Uploading code to Gistie..", 0);
	
	parameters = {
		"file_ext[gistfile1]":      "patch",
		"file_name[gistfile1]":     commit.object.subject.replace(/[^a-zA-Z0-9]/g, "-") + ".patch",
		"file_contents[gistfile1]": commit.object.patch(),
	};
	
	// TODO: Replace true with private preference
	token = Controller.getConfig_("github.token");
	login = Controller.getConfig_("github.user");
	if (token && login) {
		parameters.login = login;
		parameters.token = token;
	}
	if (!Controller.isFeatureEnabled_("publicGist"))
		parameters.private = true;
	
	var params = [];
	for (var name in parameters)
		params.push(encodeURIComponent(name) + "=" + encodeURIComponent(parameters[name]));
	params = params.join("&");
	
	var t = new XMLHttpRequest();
	t.onreadystatechange = function() {
		if (t.readyState == 4 && t.status >= 200 && t.status < 300) {
			if (m = t.responseText.match(/<a href="\/gists\/([a-f0-9]+)\/edit">/))
				notify("Code uploaded to gistie <a target='_new' href='http://gist.github.com/" + m[1] + "'>#" + m[1] + "</a>", 1);
			else {
				notify("Pasting to Gistie failed :(.", -1);
				Controller.log_(t.responseText);
			}
		}
	}
	
	t.open('POST', "https://gist.github.com/gists");
	t.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
	t.setRequestHeader('Accept', 'text/javascript, text/html, application/xml, text/xml, */*');
	t.setRequestHeader('Content-type', 'application/x-www-form-urlencoded;charset=UTF-8');
	
	try {
		t.send(params);
	} catch(e) {
		notify("Pasting to Gistie failed: " + e, -1);
	}
}

var selectCommit = function(a) {
	Controller.selectCommit_(a);
}

// Relead only refs
var reload = function() {
	commit.reloadRefs();
	showRefs();
}

var showImage = function(element, filename)
{
	element.outerHTML = '<img src="GitX://' + commit.sha + '/' + filename + '">';
	return false;
}

var enableFeature = function(feature, element)
{
	if(!Controller || Controller.isFeatureEnabled_(feature)) {
		element.style.display = "";
	} else {
		element.style.display = "none";
	}
}

var enableFeatures = function()
{
	enableFeature("gist", $("gist"))
}


var showDiff = function(data){
	$("diff").innerHTML=data;
	enableFeatures();
}

