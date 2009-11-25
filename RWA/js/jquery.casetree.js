if(jQuery) (function($){
	
	$.extend($.fn, {
		caseTree: function(o, h) {
			// Defaults
			if( !o ) var o = {};
			if( o.root == undefined ) o.root = 'morgue';
			if( o.script == undefined ) o.script = 'content/casetree.php';
			if( o.folderEvent == undefined ) o.folderEvent = 'click';
			if( o.expandSpeed == undefined ) o.expandSpeed = 500;
			if( o.collapseSpeed == undefined ) o.collapseSpeed = 500;
			if( o.expandEasing == undefined ) o.expandEasing = null;
			if( o.collapseEasing == undefined ) o.collapseEasing = null;
			if( o.loadMessage == undefined ) o.loadMessage = 'Loading...';
			
			$(this).each( function() {
				
				function showTree(c, t) {
					writeLOG('Expanding <em><b>'+t+'</b></em>...');
					$("#reftree").unbind('click',startTree);
					$(c).addClass('wait');
					$(".jqueryFileTree.start").remove();
					$.post(o.script, { dir: t }, function(data) {
						$(c).find('.start').html('');
						$(c).removeClass('wait').append(data);
						if( o.root == t ) $(c).find('UL:hidden').show(); else $(c).find('UL:hidden').slideDown({ duration: o.expandSpeed, easing: o.expandEasing });
						bindTree(c);
					});
				}
				
				function bindTree(t) {
					$(t).find('LI A').bind(o.folderEvent, function() {
						var c = $(this).parent().hasClass('case');
						var d = $(this).parent().hasClass('device');
						var k = $(this).parent().hasClass('disk');
						var p = $(this).parent().hasClass('partition');
						if( c || d || k ) {
							if( $(this).parent().hasClass('collapsed') ) {
								// Expand
								$(this).parent().find('UL').remove(); // cleanup
								showTree( $(this).parent(), escape($(this).attr('rel').match( /.*/ )) );
								$(this).parent().removeClass('collapsed').addClass('expanded');
							} else {
								// Collapse
								$(this).parent().find('UL').slideUp({ duration: o.collapseSpeed, easing: o.collapseEasing });
								$(this).parent().removeClass('expanded').addClass('collapsed');
							}
						}

						$('#resultstree')[0].style.display = (k || p) ? '' :  'none';
						$('#resultstreeempty')[0].style.display = (k || p) ? 'none' :  '';
						
						$('.selected').removeClass('selected');
						$(this).addClass('selected');
						h($(this).attr('rel'));
						return false;
					});
					// Prevent A from triggering the # on non-click events
					if( o.folderEvent.toLowerCase != 'click' ) $(t).find('LI A').bind('click', function() { return false; });
					$("#reftree").bind('click',startTree);
					writeLOG('Finished expanding <em><b>'+ ($(t).parent()[0].tagName=='DIV'?o.root:$(t).parent().find('LI A')[0].rel)+'</b></em>!');
				}
				// Loading message
				$(this).html('<ul class="jqueryFileTree start"><li class="wait">' + o.loadMessage + '<li></ul>');
				// Get the initial case list
				showTree( $(this), escape(o.root) );
				$('#resultstree')[0].style.display = 'none';
				$('#resultstreeempty')[0].style.display = '';

			});
		}
	});
	
})(jQuery);

function loadCommands(obj){
	$.post('content/cmdbox.php', { name: obj },
		function(data) {
			if(data != ''){
				$('#commands').html(data);
				writeLOG('Commands loaded successfully!');
			}
		}
	);
}

function launchCommand(src){
	$.post('content/results.php', { name: src.id, target: document.getElementById("selectedobject").value, input: '', extra: ''},
		function(data) {
			if(data != '') {
				writeLOG('Command <em>' + src.id + '</em> launched!');
				startResultsPage(data);
			}
		}
	);
	
}