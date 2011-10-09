/**
* Strelka Web Admin Console
* $Id$
* 
* Author/s:
* - Michael Granger <ged@FaerieMUD.org>
* 
*/

const ServerDefaults = {
	uuid: 'new-server',
	name: 'New Server',
	default_host: 'localhost',
	bind_addr: '0.0.0.0',
	port: '80',
	use_ssl: false
};


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
			section_func = eval( "start_" + section_funcname );
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
function start_servers( section )
{
	var _section = $(section);

	_section.find( '.actions button.create' ).click( create_server );
}


/**
 * Click event-handler: Add a row for a new server to the servers table in the same section
 * as the button that was clicked.
 * @param {JQueryObject} section The JQuery-wrapped SectionElement the table is in.
 */
function create_server( e )
{
	var button = $(e.target);
	var section = button.parent( 'section' );
	var table = section.find( 'table' ).eq( 0 );
	var tbody = table.find( 'tbody' );

	button.prop( "disabled", true );
	$( "#server-template" ).tmpl( ServerDefaults ).appendTo( tbody );
}


/**
 * DOM-ready hook -- hook up the editable elements and start any sections that have
 * corresponding functions.
 */
$( document ).ready( function() {
	$('.editable').editable( '/edit' );
	start_sections();
});


