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
				if (o.lines == undefined) o.lines = 25;
				if (o.lineOffset == undefined) o.lineOffset = 1;
			
				$(this).each(function(){
				
					function nextPage(){ goToPage(o.lineOffset / o.length + 1); }
					
					function previousPage(){ goToPage(o.lineOffset / o.length - 1); }
					
					function firstPage(){ goToPage(0);}
					
					function lastPage(){ goToPage(Number.MAX_VALUE); }
					
					function goToPage(n)
					{
						$.post(o.script, 
						{ file: o.file, lineOffset: o.lineOffset, length: o.length }, 
						function(data)
						{
							if(data != '') $(this).html = data;
						});
					}
				
				});
			}
		}
	});
})(jQuery);