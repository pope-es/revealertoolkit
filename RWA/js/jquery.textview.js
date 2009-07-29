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

				$sel = this.selector;

				$(this).each(function(){

					function nextPage(){ goToPage((document.getElementById('jquerytextviewoffset').value - 1) / document.getElementById('jquerytextviewcnt').value + 2); }

					function previousPage(){ goToPage((document.getElementById('jquerytextviewoffset').value - 1) / document.getElementById('jquerytextviewcnt').value); }

					function firstPage(){ goToPage(1);}

					function lastPage(){ goToPage(99999999); }

					function toIndex() { goToPage(parseInt(document.getElementById('jquerytextviewindex').value) + 1); }
					
					function goToPage(n)
					{
						//alert(o.file + '\n' + ((n - 1) * o.lines + 1) + '\n' + o.lines);
						$.post(o.script, 
							{ file: o.file, lineOffset: (n - 1) * o.lines + 1, lines: o.lines },
							function(data) {
								if(data != ''){
									$($sel).html(data);
									$('#jquerytextviewfirst').bind('click', firstPage);
									$('#jquerytextviewprev').bind('click', previousPage);
									$('#jquerytextviewnext').bind('click', nextPage);
									$('#jquerytextviewlast').bind('click', lastPage);
									$('#jquerytextviewgo').bind('click', toIndex );
								}
							}
						);
					}
					firstPage();
				});
			}
		}
	});
})(jQuery);