////
//// Experiment in D3 JS; no cart like in NMatrix.
////
//// Actually, at this point, D3 is only used for nice coloring.
////
//// WARNING: Since I've been experimenting with a lot of different
//// data visualizations and styles in this file for a while, there
//// are several similar and overlapping data structures produced and
//// consumed. If one were interested if/when this code got ready for
//// production, about half of them could be hacked out.
////

// 
function FacetMatrixInit(){

    // Ready logging.
    var logger = new bbop.logger();
    logger.DEBUG = true;
    function ll(str){ logger.kvetch('FM: ' + str); }
    ll('');
    ll('FacetMatrixInit start...');

    // Aliases.
    var each = bbop.core.each;
    var is_def = bbop.core.is_defined;
    var dump = bbop.core.dump;
    var hashify = bbop.core.hashify;
    var pare = bbop.core.pare;

    // Facet limit.
    var flimit = 50;

    // Element IDs.
    var results_head = '#' + 'facet_matrix_results_a_head';
    var results_div = '#' + 'facet_matrix_results_a_div';
    var bookmark_info = '#' + 'facet_matrix_info';
    var pwidget_bs3_container = '#' + 'progress-widget-bs3-container';
    var pwidget_bs3_bar = '#' + 'progress-widget-bs3-bar';

    ///
    /// Manager.
    ///

    // Okay, we're ready to go. First real job is to reconstitute the
    // manager.
    var gconf = new bbop.golr.conf(amigo.data.golr);
    var sd = new amigo.data.server();
    var solr_server = sd.golr_base();
    //var linker = new amigo.linker();
    var manager = new bbop.golr.manager.jquery(solr_server, gconf);
    manager.load_url(global_manager);    

    // Add information about the incoming bookmark to the display.
    // Do query, fq, and personality.
    var meta_cache = [];
    meta_cache.push('<em>query</em>: ' + manager.get_query());
    meta_cache.push('<em>personality</em>: ' + manager.get_personality());
    var qf_cache = [];
    each(manager.get_query_filters(),
	 function(qfd){
	     var f = qfd.filter + ':' + qfd.value;
	     if( qfd.negative_p ){
		 f = '-' + f;
	     }
	     qf_cache.push(f);
	 });
    meta_cache.push('<em>filters</em>: ' + qf_cache.join(', '));

    // Add to DOM.
    var info_list_attrs = {
	// 'class': 'amigo-facet-matrix-bookmark-list'
	'class': 'list-unstyled' // bs3
    };
    var info_list = new bbop.html.list(meta_cache, info_list_attrs);
    jQuery(bookmark_info).empty();
    jQuery(bookmark_info).append(info_list.to_string());


    // Now, make all query filters sticky (so we can use a general
    // reset later on).
    manager.set('rows', 0); // we don't need any actual rows returned
    each(manager.get_query_filters(),
	 function(fq){
	     manager.add_query_filter(fq['filter'], fq['value'], ['*']);
	 });

    ll('Completed init! Next is "init on callback."');

    // Action.
    manager.register('search', 'next step', init);
    manager.search();

    // Initialize the global matrix and node data structure.
    // var matrix = [[],[]]; // will look like this and so on; reinit later
    var val_hash = {};
    var nodes = [];
    // The initial facet lists.
    var f1 = null; // defined during init
    var f2 = null; // defined during init
    var max_val = 0;
    var value_to_color = null;

    // Get the information for the incoming terms, launch stage 02.
    //function init(response, manager){
    function init(response, search){

	ll('init start...');

	// Prevent future actions (the register would be sticky).
	search.unregister('next step');

	// Take a look at the two facets that we'll be iterating over.
	ll('Gathering batch URLs for term data...');
	var reqs_to_do = 0;
	f1 = response.facet_field(global_facet1);
	f2 = response.facet_field(global_facet2);
	ll('f1: ' + f1);
	ll('f2: ' + f2);

	// Collect the initial node information for the two axes.
	// Also collect the initial index by id for both axes.
	var id_to_index = {};
	each([f1, f2],
	     function(set){
		 each(set,
		      function(set_pair, set_index){
			  var sid = set_pair[0];
			  nodes.push({id: sid, index: set_index});
			  id_to_index[sid] = set_index;
		      });
	     });
	ll('id_to_index: ' + id_to_index);

	// Now collect the batch URLs along one facet in reference to
	// the other (arbitrary)--we should be able to get what we
	// want by just looking at once facet and checking the other
	// as we vary it.
	each(f1,
	     function(f1_pair){
		 var f1_id = f1_pair[0];

		 // Return the state.
		 // We have to reset the rows as well since rows is
		 // not sticky across a search action (think about
		 // it).
		 search.set('rows', 0); // we don't need any actual rows
		 search.set_facet_limit(flimit);
		 search.reset_query_filters();

		 search.add_query_filter(global_facet1, f1_id);
		 search.add_to_batch();

		 reqs_to_do++;
	     });

	// Fetch the data and scrape out what we want.
	var reqs_done = 0;
	var accumulator_fun = function(resp){

	    // Update progress.
	    reqs_done++;
	    var per = Math.round((reqs_done / reqs_to_do) * 100);
	    //ll(reqs_done + ' of ' + reqs_to_do + ' = ' + per + '%');
	    // jQuery(pwidget).progressbar('value', per);

	    jQuery(pwidget_bs3_bar).css('width', per + '%');
	    jQuery(pwidget_bs3_bar).attr('aria-valuenow', per);

	    // Recover the facet that we're currently looking at: 1.
    	    var fq_set = resp.parameter('fq');
	    //ll('accumu: ' + dump(fq_set));
	    var f1_name = '???';
	    each(fq_set,
		 function(fq_item){
		     // Split up each line in the set.
		     var two_part = bbop.core.first_split(':', fq_item);
    		     var fkey = two_part[0];
    		     var fval = bbop.core.dequote(two_part[1]);
    		     //ll('Looking at info for: ' + fval);
		     
		     // Check to see if it matches. If it does, that's the
		     // recovered value.
		     if( fkey == global_facet1 ){
			 f1_name = fval;		     
		     }
		 });
	    ll('got: ' + f1_name);

	    // Now grab out all of the second-facet information.
	    //ll('accumu: ' + resp.raw());
	    var incoming_facet = resp.facet_field(global_facet2);
	    var in_hash = hashify(incoming_facet);	
	    ll('in_hash: ' + dump(in_hash));
	    each(f2,
		 function(f2_line, f2_index){

		     // Figure out the value for this pair.
		     var f2_name = f2_line[0];
		     //var comb_val = f2_line[1];
		     var comb_val = 0;
		     var results_val = 0;
		     if( is_def(in_hash[f2_name]) ){
			 results_val = in_hash[f2_name];
		     }
		     ll([f1_name, f2_name].join(', ') + ': ' + results_val);

		     // Up the max.
		     if( results_val > max_val ){
			 max_val = results_val;
		     }

		     // While we're here, let's also create a lookup
		     // structure.
		     if( ! is_def(val_hash[f1_name]) ){
		     	 val_hash[f1_name] = {}; }
		     if( ! is_def(val_hash[f2_name]) ){
		     	 val_hash[f2_name] = {}; }
		     if( ! is_def(val_hash[f1_name][f2_name]) ){
		     	 val_hash[f1_name][f2_name] = results_val; }
		     if( ! is_def(val_hash[f2_name][f1_name]) ){
		     	 val_hash[f2_name][f1_name] = results_val; }
		 });
	};

	///
	/// Coloration functions using D3.
	/// We have the max_val now, so we can compute color.
	///

	// A value from our values domain in to a color in our range.
	// 0 always maps to a white-ish color.
	var c = d3.scale.linear().domain([0,max_val]).rangeRound([127,255]);
	function value_to_color_dark(val){
	    //var retval = '#efefef';
	    var retval = '#fafafa';
	    if( val != 0 ){
		var cval = c(val);
		var cinv = 255 - cval;
		var chex = cinv.toString(16);
		if( cval ){
		    if( chex.length == 1 ){ chex = '0' + chex; }
		    retval = '#' + chex + chex + chex + '';
		}
	    }
	    return retval;
	}
	function value_to_color_step(val){
	    //var retval = '#efefef';
	    var retval = '#fafafa';
	    if( val != 0 ){
		// 1-3 = pale green
		// 4-10 = yellow
		// 11-100 = orange
		// 101+ = red 
		if( val <= 3 ){
		    retval = '#79f853'; // green
		}else if( val <= 10 ){
		    //retval = '#f5ff2b'; // yellow
		    retval = '#e8f129'; // yellow
		}else if( val <= 100 ){
		    retval = '#fd953b'; // orange		
		}else{
		    retval = '#ff4e53';
		}
	    }
	    return retval;
	}	
	// Decide our coloration live at this point.
	//var value_to_color = value_to_color_dark; // default
	value_to_color = value_to_color_step; // default
	// var curr_color_selection =
	// 	jQuery("input:radio[name=color]:checked").val();
	
	// The final function is the data renderer.
	var final_fun = function(){

	    // We are done!
	    jQuery(pwidget_bs3_container).hide();

	    //render(matrix, nodes, max_val);
	    render();
	};

	search.run_batch(accumulator_fun, final_fun);
    }

    // Final stage: do the graphics and layout.
    // Initial D3 code from: http://bost.ocks.org/mike/miserables/
    //function render(matrix, nodes, max_count){
    function render(){

	ll('Render start...');

	ll('nodes: ' + dump(nodes));
	// ll('matrix: ' + dump(matrix));
	ll('val_hash: ' + dump(val_hash));
	ll('max_val: ' + dump(max_val));

	var haxis = f2;
	var hhead = global_facet2;
	var vaxis = f1;
	var vhead = global_facet1;
	// Figure out which axis is the longer one and switch.
	// if( vaxis.length > haxis.length ){
	//     haxis = f1;
	//     vaxis = f2;	    
	//     vhead = global_facet1;
	//     hhead = global_facet2;
	// }

	var td_id_to_data = {};
	function _assemble_table(haxis, vaxis){
	    
	    // Start assembling the table parts.	
	    var thead = new bbop.html.tag('thead');
	    
	    // Add what we want in the header row.
	    var head = '';
	    var title_list = [head];
	    each(haxis,
		 function(hline){
		     var ht = hline[0];
		     title_list.push(ht);
		 });
	    // Push the header row into thead.
	    each(title_list,
		 function(title_item){
		     thead.add_to('<th>' + title_item +
				  '<img style="border: 0px;" src="' +
				  sd.image_base() + '/reorder.gif" />' +
				  '</th>');
		 });
	    
	    var tbody = new bbop.html.tag('tbody');
	    
	    // Add the rows.
	    each(vaxis,
		 function(vline){
		     var vt = vline[0];

		     // Header row.
		     var rhead = '<td style="background-color:#e9effa"><b>' +
			 vt + '</b></td>';
		     var row = [rhead];
		     
		     // Data rows.
		     each(haxis,
			  function(hline){
			      var ht = hline[0];
			      var cell_val = val_hash[vt][ht];
			      
			      var color = value_to_color(cell_val);

			      // Data entry.
			      var td_attrs = {
				  style: 'background-color:' +color + ';',
				  title: vt +', '+ ht +': '+ cell_val,
				  'class': 'bbop-js-tooltip',
				  generate_id: true
			      };
			      var td =
				  new bbop.html.tag('td', td_attrs, cell_val);
			      row.push(td.to_string());

			      // Now save the data for later callback
			      // generation.
			      td_id_to_data[td.get_id()] = {
				  x: ht,
				  y: vt,
				  z: cell_val
			      };
			  });
		     
		     tbody.add_to('<tr>' + row.join('') + '</tr>');
		 });

	    //var tbl = new bbop.html.table(title_list);
	    var table_attrs = {
		'generate_id': true,
		'class': 'table' // bs3
	    };
	    var table = new bbop.html.tag('table', table_attrs);
	    table.add_to(thead);
	    table.add_to(tbody);

	    return table;
	}

	// Add table and sorting to DOM.
	jQuery(results_head).append(vhead + ' &#92; ' + hhead);
	var table_a = _assemble_table(haxis, vaxis);
	jQuery(results_div).append(table_a.to_string());
	jQuery('#' + table_a.get_id()).tablesorter();

	// Add tooltips.
	//var tt_args = {'position': {'my': 'left bottom', 'at': 'right top'}};
	var tt_args = {
	    'position': {'my': 'center bottom-5', 'at': 'center top'},
	    'tooltipClass': 'amigo-searchbar-tooltip-style'
	};
	jQuery('.bbop-js-tooltip').tooltip(tt_args);

	//
	ll('Completed render!');
	ll('Done!');
    }

    // DEBUG
    //s = search;
}
//var s;
