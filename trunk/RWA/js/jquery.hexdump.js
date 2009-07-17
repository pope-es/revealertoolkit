// jQuery Hex Dump Plugin
//
// Version 1.00
//
// Emili García Almazán
// 16 July 2009
//
// Usage: $('.hexDump').hexDump( options )
//
// Options:  file       - file to be opened; exit if not provided
//           offset     - initial position in bytes; default = 0
//           pageOffset - initial position in pages; default = 0
//           length     - length of the page in bytes; default = 400 (25 lines)
//           script     - server script used to return file data
//
// History:
//
// 1.00 - released
//
if(jQuery) (function($){
	
	$.extend($.fn, {
		hexDump: function(o) {
			// Defaults
			if (!o) var o = {};
			if (o.file != undefined) //only enter if 'file' is provided
			{
				if (o.script == undefined) o.script = 'content/hexdump.php';
				if (o.length == undefined) o.length = 400;
				if (o.offset == undefined) 
					if (o.pageOffset == undefined) o.offset = o.pageOffset = 0;
					else o.offset = o.pageOffset * o.length;
			}
			
			$(this).each(function(){
			
				function nextPage(){ goToPage(o.offset / o.length + 1); }
				
				function previousPage(){ goToPage(o.offset / o.length - 1); }
				
				function firstPage(){ goToPage(0);}
				
				function lastPage(){ goToPage(Number.MAX_VALUE); }
				
				function goToPage(n)
				{
					$.post(o.script, 
					{ file: o.file, offset: o.offset, length: o.length }, 
					function(data)
					{
						if(data != '') $(this).html = data;
					});
				}
			
			});
			
		}
	});
})(jQuery);