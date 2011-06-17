// Based on http://www.icab.de/blog/2010/01/12/search-and-highlight-text-in-uiwebview/

// We're using a global variable to store the number of occurrences
var SearchResultCount = 0;
var SearchResultShow = 0;

// helper function, recursively searches in elements and their child nodes
function HighlightAllOccurencesOfStringForElement(element,keyword) {
    if (element) {
        if (element.nodeType == 3) {        // Text node
            while (true) {
                var value = element.nodeValue;  // Search for keyword in text node
                var idx = value.toLowerCase().indexOf(keyword);
                
                if (idx < 0) break;             // not found, abort
                
                var span = document.createElement("span");
                var text = document.createTextNode(value.substr(idx,keyword.length));
                span.appendChild(text);
                span.setAttribute("id","Highlight"+SearchResultCount);
                span.setAttribute("class","Highlight");
                span.style.backgroundColor="yellow";
                span.style.color="black";
                text = document.createTextNode(value.substr(idx+keyword.length));
                element.deleteData(idx, value.length - idx);
                var next = element.nextSibling;
                element.parentNode.insertBefore(span, next);
                element.parentNode.insertBefore(text, next);
                element = text;
                SearchResultCount++;	// update the counter
            }
        } else if (element.nodeType == 1) { // Element node
            if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select') {
                for (var i=0; i<element.childNodes.length; i++) {
                    if (element.childNodes[i].nodeType==1)
                        alert("-->"+element.childNodes[i].getAttribute('class'));
                    HighlightAllOccurencesOfStringForElement(element.childNodes[i],keyword);
                }
            }
        }
    }
    return SearchResultCount;
}

// the main entry point to start the search
function HighlightAllOccurencesOfString(keyword) {
    RemoveAllHighlights();
    var c=HighlightAllOccurencesOfStringForElement(document.body, keyword.toLowerCase());
    if(c>0){
        span=$("Highlight0");
        span.style.backgroundColor="cyan";
    }
    return c;
}

function HighlightNext(){
    alert("SearchResultShow="+SearchResultShow+" SearchResultCount="+SearchResultCount);
    if(SearchResultCount>0){
        var span=$("Highlight"+SearchResultShow);
        span.style.backgroundColor="yellow";
        SearchResultShow++;
        if(SearchResultShow >= SearchResultCount)
            SearchResultShow=0;
        span=$("Highlight"+SearchResultShow);
        span.style.backgroundColor="cyan";
        location.href = "#Highlight"+SearchResultShow;
    }
}

// helper function, recursively removes the highlights in elements and their childs
function RemoveAllHighlightsForElement(element) {
    if (element) {
        if (element.nodeType == 1) {
            if (element.getAttribute("class") == "Highlight") {
                var text = element.removeChild(element.firstChild);
                element.parentNode.insertBefore(text,element);
                element.parentNode.removeChild(element);
                return true;
            } else {
                var normalize = false;
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    if (RemoveAllHighlightsForElement(element.childNodes[i])) {
                        normalize = true;
                    }
                }
                if (normalize) {
                    element.normalize();
                }
            }
        }
    }
    return false;
}

// the main entry point to remove the highlights
function RemoveAllHighlights() {
    SearchResultCount = 0;
    SearchResultShow=0;
    RemoveAllHighlightsForElement(document.body);
}
