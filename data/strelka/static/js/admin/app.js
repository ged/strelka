/**
* Strelka Web Admin Console
* $Id$
*
* Author/s:
* - Michael Granger <ged@FaerieMUD.org>
*
*/

const ConfigService = '/api/v1';

var App = {
	Models: {},
	Collections: {},
	Views: {},
	Controllers: {},

	init: function() {

		Backbone.history.start();
	}
};

/**
 * Models
 */
App.Models.Server = Backbone.Model.extend();
App.Collections.Servers = Backbone.Collection.extend({
	model: App.Models.Server,
	url: function () {
		return this.document.location.origin + ConfigService + '/servers';
	}
});



/**
 * Views
 */
App.Views.ServerListView = Backbone.View.extend({

	tagName: 'table',
	template: _.template( '#server-template' );

	initialize: function () {
		this.model.bind( "reset", this.render, this );
	},

	render: function (eventName) {
		_.each(this.model.models, function (server) {
			$( this.el ).find( 'tbody' ).
				append( this.template(server.toJSON()) );
		}, this);
		return this;
	}

});

