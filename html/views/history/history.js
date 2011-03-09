var selectCommit = function(a) {
	Controller.selectCommit_(a);
}

var openFileMerge = function(file,sha) {
	alert(file);
	alert(sha);
	Controller.openFileMerge_sha_(file,sha);
}

var showImage = function(element, filename)
{
	element.outerHTML = '<img src="GitX://' + commit.sha + '/' + filename + '">';
	return false;
}

var showCommit = function(data){
	$("commit").innerHTML=data;
}

