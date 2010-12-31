var selectCommit = function(a) {
	Controller.selectCommit_(a);
}

var showImage = function(element, filename)
{
	element.outerHTML = '<img src="GitX://' + commit.sha + '/' + filename + '">';
	return false;
}

var showDiff = function(data){
	$("diff").innerHTML=data;
}

