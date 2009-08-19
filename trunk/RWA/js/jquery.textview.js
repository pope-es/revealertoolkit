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
//           lines      - length of the page in bytes; default = 25
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
				if (o.lines == undefined) o.lines = 20;
				if (o.lineOffset == undefined) o.lineOffset = 1;
				o.direction = 0;
				
				$sel = this.selector;

				$(this).each(function(){

					function loadSearchArgs(){
						o.search = document.getElementById('jquerytextviewq') ? document.getElementById('jquerytextviewq').value : '';
						o.regexp = document.getElementById('jquerytextviewregexp') ? document.getElementById('jquerytextviewregexp').value : 0;
						o.highlight = document.getElementById('jquerytextviewhighlight') ? document.getElementById('jquerytextviewhighlight').value : 'highlight';
					}
				
					function nextMatch(){
						o.direction = 1;
						nextPage();
					}
					
					function previousMatch(){
						o.direction = -1;
						goToPage(Math.ceil((document.getElementById('jquerytextviewlastline').value) / o.lines));
					}
					
					function searchRegexp(){
						document.getElementById('jquerytextviewregexp').value = 1;
						search();
					}
					
					function search(){
						document.getElementById('jquerytextviewq').value = document.getElementById('jquerytextviewquery').value;
						o.direction = 1;
						toIndex();
					}
					
					function cancelSearch(){
						document.getElementById('jquerytextviewregexp').value = 0;
						document.getElementById('jquerytextviewq').value = document.getElementById('jquerytextviewquery').value = '';
						toIndex();
					}
					
					function highlight(){
						var bef = document.getElementById('jquerytextviewhighlight').value;
						var aft = (bef == 'highlight' ? 'nohighlight' : 'highlight');
						$('#jquerytextviewhigh').removeClass(bef == 'highlight' ? 'btncentpressed' : 'btncent').addClass(bef == 'highlight' ? 'btncent' : 'btncentpressed');
						$('.' + bef).removeClass(bef).addClass(aft);
						document.getElementById('jquerytextviewhighlight').value = aft;
					}
				
					function nextPage(){ goToPage((document.getElementById('jquerytextviewoffset').value - 1) / o.lines + 2); }

					function previousPage(){ goToPage((document.getElementById('jquerytextviewoffset').value - 1) / o.lines); }

					function firstPage(){ goToPage(1); }

					function lastPage(){ goToPage(99999999); }

					function toIndex() { goToPage(parseInt(document.getElementById('jquerytextviewindex').value)); }
					
					function goToPage(n)
					{
						loadSearchArgs();
						$.post(o.script, { file: o.file, lineOffset: (n - 1) * o.lines + 1, lines: o.lines, search: o.search, direction: o.direction, regexp: o.regexp, highlight: o.highlight },
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