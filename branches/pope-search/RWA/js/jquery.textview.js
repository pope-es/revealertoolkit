// jQuery Text Viewer Plugin
//
// Version 1.00
//
// Emili García Almazán
// 17 July 2009
//
// Usage: $('.textViewer').textViewer( options )
//
// Options:  file       - file to be opened; quit if not provided
//           lineOffset - initial position in pages; default = 1
//           lines      - length of the page in bytes -- now replaced by the value of '#lines'
//           script     - server script used to return file data
//
// History:
//
// 1.00 - released
//
if(jQuery) (function($){
	
	$.extend($.fn, {
		textViewer: function(o) {
			// Defaults
			if (!o) var o = {};
			if (o.file != undefined) //only enter if 'file' is provided
			{
				if (o.script == undefined) o.script = 'content/textview.php';
				//if (o.lines == undefined) o.lines = document.getElementById('jquerytextviewlinnum') ? document.getElementById('jquerytextviewlinnum').value : 0;
				if (o.lineOffset == undefined) o.lineOffset = 1;
				o.direction = 0;
				
				$sel = this.selector;

				$(this).each(function(){
				
					function loadSearchArgs(){
						o.search = document.getElementById('jquerytextviewq') ? document.getElementById('jquerytextviewq').value : '';
						o.regexp = document.getElementById('jquerytextviewregexp') ? document.getElementById('jquerytextviewregexp').value : 0;
						o.highlight = document.getElementById('jquerytextviewhighlight') ? document.getElementById('jquerytextviewhighlight').value : 'highlight';
						if (o.search != '') writeLOG('<b>[TEXTVIEW]</b> Search parameters sent: <b>QUERY</b>: <em>' + o.search + '</em>&nbsp; <b>REGEXP</b>: '+ (o.regexp==0?'NO':'YES') + '&nbsp; <b>HIGHLIGHT</b>: ' + (o.highlight=='highlight'?'YES':'NO'));
					}
				
					function nextMatch(){
						o.direction = 1;
						writeLOG('<b>[TEXTVIEW]</b> Searching next match...');
						nextPage();
					}
					
					function previousMatch(){
						o.direction = -1;
						writeLOG('<b>[TEXTVIEW]</b> Searching previous match...');
						goToPage(Math.ceil((document.getElementById('jquerytextviewlastline').value) / document.getElementById('jquerytextviewlinnum').value/*o.lines*/));
					}
					
					function searchRegexp(){
						document.getElementById('jquerytextviewregexp').value = 1;
						search();
					}
					
					function search(){
						var q = document.getElementById('jquerytextviewquery').value;
						if (q=='') {document.getElementById('jquerytextviewregexp').value = 0; return;}
						writeLOG('<b>[TEXTVIEW]</b> Entering search mode...');
						document.getElementById('jquerytextviewq').value = q;
						o.direction = 1;
						toIndex();
					}
					
					function cancelSearch(){
						writeLOG('<b>[TEXTVIEW]</b> Leaving search mode...');
						document.getElementById('jquerytextviewregexp').value = 0;
						document.getElementById('jquerytextviewq').value = document.getElementById('jquerytextviewquery').value = '';
						toIndex();
					}
					
					function highlight(){
						var bef = document.getElementById('jquerytextviewhighlight').value;
						writeLOG('<b>[TEXTVIEW]</b> '+(bef=='highlight'?'Disabling':'Enabling')+' highlight...');
						var aft = (bef == 'highlight' ? 'nohighlight' : 'highlight');
						$('#jquerytextviewhigh').removeClass(bef == 'highlight' ? 'btncentpressed' : 'btncent').addClass(bef == 'highlight' ? 'btncent' : 'btncentpressed');
						$('.' + bef).removeClass(bef).addClass(aft);
						document.getElementById('jquerytextviewhighlight').value = aft;
					}
				
					function nextPage(){ if (o.direction==0)writeLOG('<b>[TEXTVIEW]</b> Going to next page...'); goToPage((document.getElementById('jquerytextviewoffset').value - 1) / document.getElementById('jquerytextviewlinnum').value/*o.lines*/ + 2); }

					function previousPage(){ if (o.direction==0)writeLOG('<b>[TEXTVIEW]</b> Going to previous page...'); goToPage((document.getElementById('jquerytextviewoffset').value - 1) / document.getElementById('jquerytextviewlinnum').value/*o.lines*/); }

					function firstPage(){ writeLOG('<b>[TEXTVIEW]</b> Going to first page...'); goToPage(1); }

					function lastPage(){ writeLOG('<b>[TEXTVIEW]</b> Going to last page...'); goToPage(99999999); }

					function toIndex() { writeLOG('<b>[TEXTVIEW]</b> Going to page #'+document.getElementById('jquerytextviewindex').value+'...'); goToPage(parseInt(document.getElementById('jquerytextviewindex').value)); }
					
					function goToPage(n)
					{
						//check for previous requests (to cancel them)
						if (typeof(DataRequest)!="undefined") DataRequest.abort();
						var l = document.getElementById('jquerytextviewloading');
						if (l!=null) l.style.visibility = '';
						loadSearchArgs();
						DataRequest = $.post(o.script, { file: o.file, lineOffset: (n - 1) * (document.getElementById('jquerytextviewlinnum')?document.getElementById('jquerytextviewlinnum').value:0) + 1, lines: document.getElementById('jquerytextviewlinnum')?document.getElementById('jquerytextviewlinnum').value:0/*o.lines*/, search: o.search, direction: o.direction, regexp: o.regexp, highlight: o.highlight },
							function(data) {
								if(data != ''){
									$($sel).html(data);
									$('#jquerytextviewfirst').bind('click', firstPage);
									$('#jquerytextviewprev').bind('click', previousPage);
									$('#jquerytextviewnext').bind('click', nextPage);
									$('#jquerytextviewlast').bind('click', lastPage);
									$('#jquerytextviewgo').bind('click', toIndex);
									$('#jquerytextviewsearch').bind('click', search);
									$('#jquerytextviewsrchreg').bind('click', searchRegexp);
									$('#jquerytextviewup').bind('click', previousMatch);
									$('#jquerytextviewdown').bind('click', nextMatch);
									$('#jquerytextviewhigh').bind('click', highlight);
									$('#jquerytextviewcancel').bind('click', cancelSearch);
									writeLOG('<b>[TEXTVIEW]</b> Page #'+$('#jquerytextviewindex')[0].value+' retrieved successfully!');
								}
							}
						);
						o.direction = 0;
					}
					firstPage();
				});
			}
		}
	});
})(jQuery);