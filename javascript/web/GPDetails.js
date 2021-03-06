////
//// A lot of the commented out stuff in the other completely gone here.
////

//
function GPDetailsInit(){

    // Logger.
    var logger = new bbop.logger();
    logger.DEBUG = true;
    function ll(str){ logger.kvetch('GP: ' + str); }    

    ll('');
    ll('GPDetails.js');
    ll('GPDetailsInit start...');

    // Use jQuery UI to tooltip-ify doc.
    var tt_args = {'position': {'my': 'left bottom', 'at': 'right top'}};
    jQuery('.bbop-js-tooltip').tooltip(tt_args);

    // Tabify the layout if we can (may be in a non-tabby version).
    var dtabs = jQuery("#display-tabs");
    if( dtabs ){
	ll('Apply tabs...');
	jQuery("#display-tabs").tabs();
	jQuery("#display-tabs").tabs('option', 'active', 0);
    }
    
    // Ready the configuration that we'll use.
    var gconf = new bbop.golr.conf(amigo.data.golr);
    var sd = new amigo.data.server();
    var solr_server = sd.golr_base();

    // Setup the annotation profile and make the annotation document
    // category and the current acc sticky in the filters.
    var linker = new amigo.linker();
    var handler = new amigo.handler();
    var gps_args = {
	'linker': linker,
	'handler': handler,
	'spinner_search_source' : sd.image_base() + '/waiting_ajax.gif'
    };
    var gps = new bbop.widget.search_pane(solr_server, gconf,
					  'display-associations',
					  gps_args);
    // Set the manager profile.
    gps.set_personality('annotation'); // profile in gconf
    gps.include_highlighting(true);

    // Two sticky filters.
    gps.add_query_filter('document_category', 'annotation', ['*']);
    gps.add_query_filter('bioentity', global_acc, ['*']);

    // Download limit.
    //var dlimit = 7500;
    var dlimit = 100000;

    // Add a term id download button.
    var btmpl = bbop.widget.display.button_templates;
    var id_download_button =
	btmpl.field_download('Download term IDs (up to ' + dlimit + ')',
			     dlimit, ['annotation_class']);
    gps.add_button(id_download_button);

    // Get the interface going.
    gps.establish_display();
    gps.reset();

    //
    ll('GPDetailsInit done.');
}
