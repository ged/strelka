/**
* Strelka Web Admin Console
* $Id$
* 
* Author/s:
* - Michael Granger <ged@FaerieMUD.org>
* 
*/



/**
 * A little toggle-able element plugin.
 */
(function( jQuery, undefined ) {

	/**
	 * Click callback for toggleable elements.
	 */
	function toggleContents( e ) {
		console.debug( "Click! Toggle: %o", e.target );
		e.data.elem.toggleClass( 'enabled' );
	}

	jQuery.fn.toggleable = function() {
		console.debug( "Making %o toggleable.", this );
		var toggle_elem = this;

		return this.find( '.target' ).each( function() {
			var $this = $(this);
			$this.bind( 'click.toggleable', {elem: toggle_elem}, toggleContents );
		});
	};

})( jQuery );


const ServerDefaults = {
	uuid:         'new-server',
	name:         'New Server',
	default_host: 'localhost',
	bind_addr:    '0.0.0.0',
	port:         '80',
	use_ssl:      false,
	access_log:   '/logs/access.log',
	error_log:    '/logs/error.log',
	pid_file:     '/run/mongrel2.pid'
};

const AjaxSettings = {
	contentType: 'application/json',
	dataType: 'json'
};



/**
 * 
 */
function handle_backend_error( e, jqxhr, settings, exception )
{
	var desc = { event: e, jqxhr: jqxhr, settings: settings, exception: exception };

	console.error( "Backend error: %o", desc );
	$( '#error-template' ).tmpl( desc ).appendTo( '#overlay' );
	$( '#overlay' ).overlay({ load: true });
}


/**
 * Call functions for sections if they're defined. A section with an ID of 'foo' will
 * cause a function called start_foo() to be called with the section's DOM object as its
 * argument.
 */
function start_sections()
{
	$('section').each( function() {
		var sectionid = this.id;
		var section_funcname = sectionid.replace( /-/g, '_' );
		var section_func;

		try {
			section_func = eval( "start_" + section_funcname + "_section" );
		} catch( e ) {
			console.debug( "Caught error: %o", e );
			console.debug( "No start function for '%s'.", sectionid );
			section_func = null;
		};

		if ( typeof(section_func) == 'function' ) {
			console.info( "Starting %s content section with %o", sectionid, section_func );
			console.group( sectionid );
			section_func( this );
			console.groupEnd();
		}
	});
}


/**
 * Section hook -- called when there is a 'servers' section in the DOM.
 * @param {SectionElement} section The 'server' <section> element.
 */
function start_servers_section( elem )
{
	var section = $(elem);
	section.find( '.actions button.create' ).click( create_server );

	var req = $.getJSON( '/api/v1/servers' );
	req.done( function(servers) {
		var tbody = section.find( 'table tbody.data' );
		console.debug( "Existing servers: %o", servers );

		for ( var i in servers ) {
			var server = servers[ i ];
			console.debug( "  server: %s", server.uuid );
			var row = $( "#server-template" ).tmpl( server ).appendTo( tbody );
			row.data( 'server', server );
		}

		tbody.find( 'tr.server' ).bind( 'dblclick.editable', function(e) {
			var target = $( e.target );
			var row = target.parents( 'tr' ).eq( 0 );
			make_row_editable( row );
		} );
	});

}


/**
 * Make the specified {row} editable.
 * @param {row} Object the jQuery object for a HTMLTableRow that should have editablility
 *                     added to its columns.
 */
function make_row_editable( row )
{
	var server = row.data( 'server' );
	console.debug( "Making row editable: %o", row );
	row.addClass( 'unsaved' ).unbind( 'dblclick.editable' );

	row.find( 'td.editable' ).editable( save_field, {
		data:   edit_field,
		onblur: 'submit',
		select: true,
		server: server
	});
	row.find( 'td.toggle' ).toggleable();
	row.find( 'td.controls button.save' ).click( save_server_edits );
	row.find( 'td.controls button.cancel' ).click( cancel_server_edits );

	row.bind( 'keydown.editable', tab_between_fields );

	return true;
}


/**
 * jEditable callback -- called with the cell data before populating the editable form
 * field with whatever is returned. This function strips any A tag around the cell contents
 * and stashes it so it can be restored after the edit.
 * @param {String} value     the raw contents of the field being edited.
 * @param {Object} settings  the hash of jEditable settings in effect.
 */
function edit_field( value, settings )
{
	var $value = $( value );

	if ( $value.html() ) {
		return $value.html();
	} else {
		return value;
	}
}


/**
 * jEditable callback -- called when one of the fields of a server is edited and saved.
 * @param {String} value     the edited contents of the field.
 * @param {Object} settings  the hash of jEditable settings in effect.
 */
function save_field( value, settings )
{
	var $this = $(this);
	if ( $this.attr('data-binding') == 'id' || $this.attr('data-binding') == 'uuid' ) {
		if ( settings.server ) {
			var anchor = $("<a />");
			anchor.attr( 'href', settings.server.uri );
			anchor.html( value );
			return anchor;
		} else {
			return value;
		}
	} else {
		return value;
	}
}


/**
 * Button click callback -- save edits made to a server in the servers table when the
 * Save button is clicked.
 */
function save_server_edits( e )
{
	var clicked_button = $(e.target);
	var row = clicked_button.parents( 'tr.server' ).eq( 0 );
	var data = extract_row_data( row );
	var json = JSON.stringify( data );

	console.debug( "Would save server from row values: %s", json );
	$.post( 'server', json ).success( update_server_table );
}


/**
 * Ajax callback -- called on a successful POST to create a new server.
 */
function update_server_table( data, status, jqxhr ) {
	var $this = $(this);
	console.debug( "Success callback: data = %o, status = %s, this = %o", data, status, this );
}



/**
 * Extract an object from the given +row+, using data-binding values as the key
 * and the column's value as the value.
 */
function extract_row_data( row )
{
	var obj = jQuery.extend( {}, ServerDefaults );

	$(row).find( 'td[data-binding]' ).each( function(i) {
		var $this = $(this);
		var key = $this.attr( 'data-binding' );
		var value = null;

		/* Extract the value as a boolean for toggle fields */
		if ( $this.hasClass('toggle') ) {
			value = $this.hasClass('enabled') ? 1 : 0;
		}
		/* ...or from the contents of the anchor if there is one */
		else if ( $this.children('a').size() ) {
			value = $this.children('a').html();
		}
		/* ...or just from the value in the column */
		else {
			value = $this.html();
		}

		obj[ key ] = value;
	});

	return obj;
}



/**
 * Button click callback -- clear edits made to a server in the servers table when the
 * Cancel button is clicked.
 */
function cancel_server_edits( e )
{
	var clicked_button = $(e.target);
	var row = clicked_button.parents( 'tr.server' ).eq( 0 );
	var server = row.data( 'server' );

	// If it's an existing server, just revert the row values back to their original
	// values
	if ( !server ) {
		console.debug( "Cancelled creation of new server." );
		row.remove();
	} else {
		console.debug( "Cancelled edit of server %s", server.uuid );
		row.find( 'td[data-binding]' ).
			each( function() { restore_original_column_value(this, server); } ).
			unbind( 'click.editable' );
		row.bind( 'dblclick.editable', make_row_editable ).removeClass( 'unsaved' );
	}

}


/**
 * Extract the original value of the given {td} from the {server} object and restore
 * it, preserving links and toggle columns.
 */
function restore_original_column_value( td, server ) {
	var $td = $(td);
	var field = $td.attr('data-binding');

	if ( field ) {
		console.debug( "Looking for edits to: %o (%s)", td, field );
		var original_value = server[ field ];

		if ( original_value ) {
			console.debug( "Undoing edit to: %o. Original value = %o", this, original_value );

			/* State for a toggle is the presence or absence of the 'enabled' class */
			if ( $td.hasClass('toggle') ) {
				if ( original_value ) {
					$td.addClass( 'enabled' );
				} else {
					$td.removeClass( 'enabled' );
				}
			}
			// Restore the text inside anchors
			else if ( $td.children('a').size() ) {
				$td.children('a').html( original_value );
			} else {
				$td.text( original_value );
			}
		}
	}
}



/**
 * Click event-handler: Add a row for a new server to the servers table in the same section
 * as the button that was clicked.
 * @param {JQueryObject} section The JQuery-wrapped SectionElement the table is in.
 */
function create_server( e )
{
	var button = $(e.target);
	var section = button.parents( 'section' ).eq( 0 );
	var table = section.find( 'table' ).eq( 0 );
	var tbody = table.find( 'tbody.data' );

	button.prop( "disabled", true );
	$.getJSON( '/uuid' ).done( function(uuid) {
		var values = jQuery.extend( {}, ServerDefaults, {uuid: uuid} );
		var new_row = $( "#server-template" ).tmpl( values ).appendTo( tbody );
		new_row.find( '.uuid' ).addClass( 'editable' );

		make_row_editable( new_row );
		button.prop( "disabled", false );
	} );
}


/**
 * Keydown event handler -- support tabbing between fields.
 * @param {Event} e the keydown event.
 */
function tab_between_fields( e )
{
	if ( e.which == 9 ) {
		var cell = $(e.target).parents( 'td' );
		var target = null;

		if ( e.shiftKey ) {
			console.debug( "Shift-tab: targeting previous column." );
			target = cell.prev();
		} else {
			console.debug( "Tab: targeting next column." );
			target = cell.next();
		}

		if ( !target ) { return; }

		if ( target.hasClass('editable') ) {
			console.debug( "Tabbing from %o to %o", cell, target );
			e.preventDefault();
			target.click();
		} else {
			console.debug( "No editable cell to tab to. Ignoring." );
		}
	}
}


/**
 * DOM-ready hook -- hook up the editable elements and start any sections that have
 * corresponding functions.
 */
$( document ).ready( function() {
	$.ajaxSetup( AjaxSettings );
	$('#overlay').ajaxError( handle_backend_error );
	start_sections();
});


