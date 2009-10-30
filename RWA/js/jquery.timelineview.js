// jQuery Timeline Viewer Plugin
//
// Version 1.00
//
// Emili García Almazán
// 17 July 2009
//
// Usage: $('.timelineViewer').timelineViewer( options )
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
		timelineViewer: function(o) {
			// Defaults
			if (!o) var o = {};
			if (o.file != undefined) //only enter if 'file' is provided
			{
				if (o.script == undefined) o.script = 'content/timelineview.php';
				if (o.lineOffset == undefined) o.lineOffset = 1;
				if (o.delimiter == undefined) o.delimiter = ',';
				if (o.expression == undefined) o.expression = '';
				if (o.columns == undefined) o.columns = '';
				if (o.headers == undefined) o.headers = '';
				o.direction = 0;
				
				$sel = this.selector;

				$(this).each(function(){
				
					function loadSearchArgs(){
						o.search = document.getElementById('jquerytimelineviewq') ? document.getElementById('jquerytimelineviewq').value : '';
						o.regexp = document.getElementById('jquerytimelineviewregexp') ? document.getElementById('jquerytimelineviewregexp').value : 0;
						o.highlight = document.getElementById('jquerytimelineviewhighlight') ? document.getElementById('jquerytimelineviewhighlight').value : 'highlight';
						if (o.search != '') writeLOG('<b>[TIMELINEVIEW]</b> Search parameters sent: <b>QUERY</b>: <em>' + o.search + '</em>&nbsp; <b>REGEXP</b>: '+ (o.regexp==0?'NO':'YES') + '&nbsp; <b>HIGHLIGHT</b>: ' + (o.highlight=='highlight'?'YES':'NO'));
					}
				
					function nextMatch(){
						o.direction = 1;
						writeLOG('<b>[TIMELINEVIEW]</b> Searching next match...');
						nextPage();
					}
					
					function previousMatch(){
						o.direction = -1;
						writeLOG('<b>[TIMELINEVIEW]</b> Searching previous match...');
						goToPage(Math.ceil((document.getElementById('jquerytimelineviewlastline').value) / document.getElementById('jquerytimelineviewlinnum').value/*o.lines*/));
					}
					
					function searchRegexp(){
						document.getElementById('jquerytimelineviewregexp').value = 1;
						search();
					}
					
					function search(){
						var q = document.getElementById('jquerytimelineviewquery').value;
						if (q=='') {document.getElementById('jquerytimelineviewregexp').value = 0; return;}
						writeLOG('<b>[TIMELINEVIEW]</b> Entering search mode...');
						document.getElementById('jquerytimelineviewq').value = q;
						o.direction = 1;
						toIndex();
					}
					
					function cancelSearch(){
						writeLOG('<b>[TIMELINEVIEW]</b> Leaving search mode...');
						document.getElementById('jquerytimelineviewregexp').value = 0;
						document.getElementById('jquerytimelineviewq').value = document.getElementById('jquerytimelineviewquery').value = '';
						toIndex();
					}
					
					function highlight(){
						var bef = document.getElementById('jquerytimelineviewhighlight').value;
						writeLOG('<b>[TIMELINEVIEW]</b> '+(bef=='highlight'?'Disabling':'Enabling')+' highlight...');
						var aft = (bef == 'highlight' ? 'nohighlight' : 'highlight');
						$('#jquerytimelineviewhigh').removeClass(bef == 'highlight' ? 'btncentpressed' : 'btncent').addClass(bef == 'highlight' ? 'btncent' : 'btncentpressed');
						$('.' + bef).removeClass(bef).addClass(aft);
						document.getElementById('jquerytimelineviewhighlight').value = aft;
					}
				
					function nextPage(){ if (o.direction==0)writeLOG('<b>[TIMELINEVIEW]</b> Going to next page...'); goToPage((document.getElementById('jquerytimelineviewoffset').value - 1) / document.getElementById('jquerytimelineviewlinnum').value/*o.lines*/ + 2); }

					function previousPage(){ if (o.direction==0)writeLOG('<b>[TIMELINEVIEW]</b> Going to previous page...'); goToPage((document.getElementById('jquerytimelineviewoffset').value - 1) / document.getElementById('jquerytimelineviewlinnum').value/*o.lines*/); }

					function firstPage(){ writeLOG('<b>[TIMELINEVIEW]</b> Going to first page...'); goToPage(1); }

					function lastPage(){ writeLOG('<b>[TIMELINEVIEW]</b> Going to last page...'); goToPage(99999999); }

					function toIndex() { writeLOG('<b>[TIMELINEVIEW]</b> Going to page #'+document.getElementById('jquerytimelineviewindex').value+'...'); goToPage(parseInt(document.getElementById('jquerytimelineviewindex').value)); }
					
					function goToPage(n)
					{
						loadSearchArgs();
						$.post(o.script, { file: o.file, lineOffset: (n - 1) * (document.getElementById('jquerytimelineviewlinnum')?document.getElementById('jquerytimelineviewlinnum').value:0) + 1, lines: document.getElementById('jquerytimelineviewlinnum')?document.getElementById('jquerytimelineviewlinnum').value:0/*o.lines*/, search: o.search, direction: o.direction, regexp: o.regexp, highlight: o.highlight, headers: o.headers, delimiter: o.delimiter, columns: o.columns, expression: o.expression },
							function(data) {
								if(data != ''){
									$($sel).html(data);
									$('#jquerytimelineviewfirst').bind('click', firstPage);
									$('#jquerytimelineviewprev').bind('click', previousPage);
									$('#jquerytimelineviewnext').bind('click', nextPage);
									$('#jquerytimelineviewlast').bind('click', lastPage);
									$('#jquerytimelineviewgo').bind('click', toIndex);
									$('#jquerytimelineviewsearch').bind('click', search);
									$('#jquerytimelineviewsrchreg').bind('click', searchRegexp);
									$('#jquerytimelineviewup').bind('click', previousMatch);
									$('#jquerytimelineviewdown').bind('click', nextMatch);
									$('#jquerytimelineviewhigh').bind('click', highlight);
									$('#jquerytimelineviewcancel').bind('click', cancelSearch);
									writeLOG('<b>[TIMELINEVIEW]</b> Page #'+$('#jquerytimelineviewindex')[0].value+' retrieved successfully!');
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