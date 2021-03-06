####
#### TODO/BUG: session_id needs to be stored as a cookie, caching
#### reasons, etc.
####
#### TODO: replace internal $core calls with the one saved in
#### AmiGO::WebApp::$self as much as possible (save on things like
#### species caching, etc.)
####

package AmiGO::WebApp::HTMLClient;
use base 'AmiGO::WebApp';

use strict;
use utf8;
use Data::Dumper;
#use AmiGO::JavaS

##
use AmiGO::WebApp::Input;
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::Redirect;

# ## Internal workers.
# use AmiGO::ChewableGraph;

## Real external workers.
use AmiGO::Worker::GOlr::Term;
use AmiGO::Worker::GOlr::GeneProduct;
#use AmiGO::Worker::GOlr::ComplexAnnotationUnit;
use AmiGO::Worker::GOlr::ComplexAnnotationGroup;
use AmiGO::External::QuickGO::Term;
use AmiGO::External::XML::GONUTS;
#use AmiGO::External::Raw;

## TODO: Maybe make this a worker later when we get the feel for it.
use AmiGO::External::JSON::Solr::GOlr::Search;


##
sub setup {

  my $self = shift;

  $self->{STATELESS} = 0;

  ## Configure how the session stuff is going to be handled when and
  ## if it is necessary.
  $self->session_config(CGI_SESSION_OPTIONS =>
			["driver:File",
			 $self->query,
			 {Directory=>
			  $self->{CORE}->amigo_env('AMIGO_SESSIONS_ROOT_DIR')}
			],
			COOKIE_PARAMS => {-path  => '/'},
			SEND_COOKIE => 1);

  $self->mode_param('mode');
  $self->start_mode('landing');
  $self->error_mode('mode_fatal');
  $self->run_modes(
		   ## Standard.
		   'landing'             => 'mode_landing',
		   #'search'              => 'mode_live_search',
		   'search'              => 'mode_search',
		   'specific_search'     => 'mode_search',
		   'browse'              => 'mode_browse',
		   'term'                => 'mode_term_details',
		   'gene_product'        => 'mode_gene_product_details',
		   'complex_annotation'  => 'mode_complex_annotation_details',
		   'visualize'           => 'mode_visualize',
		   'visualize_freeform'  => 'mode_visualize_freeform',
		   'software_list'       => 'mode_software_list',
		   'schema_details'      => 'mode_schema_details',
		   'load_details'        => 'mode_load_details',
		   'medial_search'       =>  'mode_medial_search',
		   ## ???
		   'phylo_graph'         => 'mode_phylo_graph',
		   ## Fallback.
		   'simple_search'       => 'mode_simple_search',
		   'AUTOLOAD'            => 'mode_exception'
		  );
}

##
sub mode_landing {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile();

  ## Page settings.
  $self->set_template_parameter('page_name', 'landing');
  $self->set_template_parameter('page_title', 'AmiGO 2: Welcome');
  #$self->set_template_parameter('content_title', 'AmiGO 2');

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('LandingGraphs.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'LandingGraphsInit();'
     ],
     content =>
     [
      'pages/landing.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  #return $self->generate_template_page_with();
  return $self->generate_template_page_with({search=>0});
}


##
sub mode_browse {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile();

  ## Page settings.
  $self->set_template_parameter('page_name', 'browse');
  $self->set_template_parameter('page_title', 'AmiGO 2: Browse');
  $self->set_template_parameter('content_title', 'Browse');

  ## Get the layout info to describe which buttons should be
  ## generated.
  #my $bbinfo = $self->{CORE}->get_amigo_layout('AMIGO_LAYOUT_BROWSE');
  #$self->set_template_parameter('browse_button_info', $bbinfo);
  ## Pick the first to be the default.
  #my $sb = $$bbinfo[0]->{id};
  #$self->set_template_parameter('starting_button', $sb);

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('Browse.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'BrowseInit();'
     ],
     content =>
     [
      'pages/browse.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


##
sub mode_simple_search {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('simple_search');

  ## Tally up if we have insufficient information to do a query.
  my $insufficient_info_p = 2;

  ## Pull our query parameter.
  my $q = $params->{query};
  if( ! defined $q || $q eq '' ){
    #$self->add_mq('warning', 'No search query was defined--please try again.');
  }else{
    $self->set_template_parameter('query', $q);
    $self->{CORE}->kvetch('query: ' . $q);
    $insufficient_info_p--;
  }

  ## Pull our golr_class parameter.
  my $gc = $params->{golr_class};
  if( ! defined $gc || $gc eq '' ){
    # $self->add_mq('warning',
    # 		  'No search category was defined--please try again.');
  }else{
    $self->set_template_parameter('golr_class', $gc);
    $self->{CORE}->kvetch('golr_class: ' . $gc);
    $insufficient_info_p--;
  }

  ## Pull our page parameter. 1 if nothing else.
  my $page = $self->{CORE}->atoi($params->{page}) || 1;
  $self->set_template_parameter('page_number', $page);

  ## See if there are any results.
  my $results_p = 0;
  my $results_docs = undef;

  ## Only attempt a search if there is not insufficient
  ## information. Otherwise, we'll let the warnings speak for
  ## themselves.
  if( $insufficient_info_p != 0 ){
    $self->set_template_parameter('search_performed_p', 0);
  }else{
    $self->set_template_parameter('search_performed_p', 1);

    ## Actually do the search up proper.

    my $gs = AmiGO::External::JSON::Solr::GOlr::Search->new();
    #$self->{CORE}->kvetch("target: " . $gs->{AEJS_BASE_URL});
    my $results_ok_p = $gs->smart_query($q, $gc, $page);

    $results_docs = $gs->docs();
    my $results_total = $gs->total();
    my $results_count = $gs->count();
    if( $results_ok_p && $results_docs && $gs->count() > 0 ){
      $results_p = 1;
    }

    ## Set with our findings.
    $self->set_template_parameter('results_p', $results_p);
    $self->set_template_parameter('results', $results_docs);
    $self->set_template_parameter('results_total', $results_total);
    $self->set_template_parameter('results_count', $results_count);

    ## See if we can get links.
    ## BUG: Right now, we only understand internal links.
    my $results_links_local = {};
    foreach my $doc (@{$results_docs}) {
      #my $rdoc = $results_docs->{$rid};
      if( $doc->{id} ){
	my $linkable_field = ['annotation_class', 'bioentity',
			      'evidence_with',
			      'taxon',
			      'panther_family'];
	foreach my $curr_field (@$linkable_field){
	  ## Make sure we're dealing with a list.
	  my $curr_field_val_list = $doc->{$curr_field} || [];
	  $curr_field_val_list = [$curr_field_val_list]
	    if ref $curr_field_val_list ne 'ARRAY';
	  foreach my $curr_field_val (@$curr_field_val_list){
	    if( $curr_field_val ){
	      if( $curr_field eq 'annotation_class' ){
		$results_links_local->{$curr_field_val} =
		  $self->{CORE}->get_interlink({mode => 'term_details',
						arg => {acc=>$curr_field_val}});
	      }elsif( $curr_field eq 'bioentity' ){
		$results_links_local->{$curr_field_val} =
		  $self->{CORE}->get_interlink({mode => 'gp_details',
						arg => {gp=>$curr_field_val}});
	      }else{
		## All others for through the general abbs linker.
		my($cdb, $ckey) =
		  $self->{CORE}->split_gene_product_acc($curr_field_val);
		my $link_try = $self->{CORE}->database_link($cdb, $ckey);
		if( $link_try ){
		  $results_links_local->{$curr_field_val} = $link_try;
		}
	      }
	    }
	  }
	}
      }
    }
    #$self->{CORE}->kvetch('results_links_local: ' . Dumper($results_links_local));
    $self->set_template_parameter('results_links_local', $results_links_local);

    ## And highlighting.
    my $hlite = $gs->highlighting();
    #$self->{CORE}->kvetch('highlighting: ' . Dumper($hlite));
    $self->set_template_parameter('highlighting', $hlite);

    ## Take care of paging.
    my $next_page_url =
      $self->{CORE}->get_interlink({mode => 'simple_search',
				    arg => {'query' => $q,
					    'golr_class'=> $gc,
					    'page' => $page + 1},
				    optional => {'frag' => 'nav_anchor'}});
    my $prev_page_url =
      $self->{CORE}->get_interlink({mode => 'simple_search',
				    arg => {'query' => $q,
					    'golr_class'=> $gc,
					    'page' => $page - 1},
				    optional => {'frag' => 'nav_anchor'}});
    my $first_page_url =
      $self->{CORE}->get_interlink({mode => 'simple_search',
				    arg => {'query' => $q,
					    'golr_class'=> $gc,
					    'page' => 1},
				    optional => {'frag' => 'nav_anchor'}});
    my $last_page_url =
      $self->{CORE}->get_interlink({mode => 'simple_search',
				    arg => {'query' => $q,
					    'golr_class'=> $gc,
					    'page' => $gs->last_page()},
				    optional => {'frag' => 'nav_anchor'}});
    $self->set_template_parameter('first_page_url', $first_page_url);
    $self->set_template_parameter('last_page_url', $last_page_url);
    $self->set_template_parameter('next_page_url', $next_page_url);
    $self->set_template_parameter('prev_page_url', $prev_page_url);
    $self->set_template_parameter('next_page_p', $gs->more_p());
    $self->set_template_parameter('range_high', $gs->range_high($page));
    $self->set_template_parameter('range_low', $gs->range_low($page));
    $self->set_template_parameter('range', $gs->count());

    ## Nice to know the category that we searched in.
    my $dc = $self->{CORE}->golr_class_document_category($gc);
    $self->set_template_parameter('document_category', $dc);

    ## Okay, the main search stuff is done, now let's sort out all of
    ## the information needed for the headers.
    my $gci = $self->{CORE}->golr_class_info($gc);
    $self->set_template_parameter('golr_class_info', $gci);
    #$self->{CORE}->kvetch('golr_class_info: ' . Dumper($gci));
    my $result_weights_hash = $self->{CORE}->golr_class_weights($gc, 'result');
    my @results_order = sort {
      $result_weights_hash->{$b} <=> $result_weights_hash->{$a}
    } (keys %{$result_weights_hash});
    $self->set_template_parameter('results_order', \@results_order);
    #$self->{CORE}->kvetch('results_order: ' . Dumper(\@results_order));
  }

  ## Page settings.
  $self->set_template_parameter('page_name', 'simple_search');
  $self->set_template_parameter('page_title', 'AmiGO 2: Simple Search');
  $self->set_template_parameter('content_title', 'Simple Search');

  ## Grab the config info for the simple search form construction.
  my $ss_info = $self->{CORE}->golr_class_info_list_by_weight(25);
  $self->set_template_parameter('simple_search_form_info', $ss_info);

  ## The rest of our environment.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();'
     ],
     content =>
     [
      'pages/simple_search.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


## WARNING: Without pivot tables, this is expensive, taking multiple
## passes at the server to assemble the necessarily grouped data.
sub mode_medial_search {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('medial_search');
  ## Deal with the different types of dispatch we might be facing.
  $params->{query} = $self->param('query')
    if ! $params->{query} && $self->param('query');
  $self->{CORE}->kvetch(Dumper($params));
  my $q = $params->{query};

  ## Pull our query parameter.
  if( ! defined $q || $q eq '' ){
    my $str = "No query found. Please go back and try again.";
    return $self->mode_fatal($str);
  }

  $self->set_template_parameter('query', $q);
  $self->{CORE}->kvetch('query: ' . $q);

  ## Get the layout info to describe which personalities are
  ## available.
  my $stinfo = $self->{CORE}->get_amigo_layout('AMIGO_LAYOUT_SEARCH');
  my $stinfo_hash = {};
  my $personality_list = [];
  my $accu_results = 0;
  foreach my $sti (@$stinfo){

    my $st_id = $sti->{id};
    my $st_name = $sti->{display_name};
    my $st_desc = $sti->{description};
    my $st_cat = $sti->{document_category};
    my $st_weight = $sti->{weight};

    $stinfo_hash->{$st_id} =
      {
       'id' => $st_id,
       'name' => $st_name,
       'description' => $st_desc,
       'document_category' => $st_cat,
       'weight' => $st_weight,
       'count' => 0,
       'link' => $self->{CORE}->get_interlink({mode=>'live_search',
					       arg => {
						       type => $st_id,
						       query => $q,
						      }}),
      };

    #push @$personality_list, $st_id;
    #$personality_list = [$st_id];
    my $gs = AmiGO::External::JSON::Solr::GOlr::Search->new();
    my $cqs = $gs->comfy_query_string($q);
    #my $results_ok_p = $gs->counting_query($cqs, $personality_list);
    my $results_ok_p = $gs->counting_query($cqs, $st_id);
    #my $result_facets = $gs->facet_field('document_category');
    my $results_total = $gs->total();
    if( $results_total ){
      $stinfo_hash->{$st_id}{count} = $results_total;
      $accu_results += $results_total;
    }
  }

  my $results_p = 0;
  if( $accu_results ){
    $results_p = 1;
  }

  ## Make our data into a weight-ordered list for rendering.
  my @info_array =
    sort { return $b->{weight} <=> $a->{weight}; } values %$stinfo_hash;
  $self->{CORE}->kvetch('results_info: ' . Dumper(\@info_array));

  ## Set with our findings.
  $self->set_template_parameter('results_info', \@info_array);
  $self->set_template_parameter('results_p', $results_p);
  #$self->set_template_parameter('results_total', $results_total);
  #$self->set_template_parameter('results_count', $results_count);
  #$self->{CORE}->kvetch('results_order: ' . Dumper(\@results_order));

  ## Page settings.
  $self->set_template_parameter('page_name', 'medial_search');
  $self->set_template_parameter('page_title',
				'AmiGO 2: Advanced Search Directory');
  $self->set_template_parameter('content_title', 'Advanced Search Directory');

  ## The rest of our environment.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();'
     ],
     content =>
     [
      'pages/medial_search.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


##
sub mode_software_list {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile();

  ## Page settings.
  $self->set_template_parameter('page_name', 'software_list');
  $self->set_template_parameter('page_title', 'AmiGO 2: Tools and Resources');
  $self->set_template_parameter('content_title', 'Tools and Resources');

  ## Where would the ancient demos page hide...?
  my $foo = $self->{CORE}->amigo_env('AMIGO_CGI_PARTIAL_URL');
  $self->set_template_parameter('OLD_LOC', $foo);

  ## Get Galaxy, and add a variable for it in the page.
  $self->set_template_parameter('GO_GALAXY',
				$self->{CORE}->amigo_env('AMIGO_PUBLIC_GALAXY_URL'));

  # ## DEBUG:
  # ## Let's try getting some random messages out.
  # $self->add_mq('warning', 'warning floats to middle');
  # $self->add_mq('notice', 'Hello, World!');
  # $self->add_mq('error', 'error floats to top');
  # $self->add_mq('notice', 'Part2: Hello, World!');

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      #'com.jquery.tablesorter',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      #'com.jquery.tablesorter',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();'
     ],
     content =>
     [
      'pages/software_list.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


##
sub mode_schema_details {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile();

  ## Page settings.
  $self->set_template_parameter('page_name', 'schema_details');
  $self->set_template_parameter('page_title', 'AmiGO 2: Schema Details');
  $self->set_template_parameter('content_title', 'Instance Schema Details');

  ## Get Galaxy, and add a variable for it in the page.
  $self->set_template_parameter('GO_GALAXY',
				$self->{CORE}->amigo_env('AMIGO_PUBLIC_GALAXY_URL'));

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      #'com.jquery.tablesorter',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'com.jquery.tablesorter',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('Schema.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'SchemaInit();'
     ],
     content =>
     [
      'pages/schema_details.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


##
sub mode_load_details {

  my $self = shift;

  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile();

  ## Load in the GOlr timestamp details.
  my $glog = $self->{CORE}->amigo_env('GOLR_TIMESTAMP_LOCATION');
  my $ts_details = $self->{CORE}->golr_timestamp_log($glog);
  if( $ts_details && scalar(@$ts_details) ){
    $self->set_template_parameter('TS_DETAILS_P', 1);

    ## We have something, now let's sort out the ontology and GAF sections.
    my $ts_ont = [];
    my $ts_gaf = [];
    foreach my $item (@$ts_details){
      if( $item->{type} eq 'ontology' ){
	push @$ts_ont, $item;
      }elsif( $item->{type} eq 'gaf' ){
	push @$ts_gaf, $item;
      }else{
	## Not covering anything else yet.
      }
    }

    #die "ARGH! " . scalar(@$ts_gaf);

    $self->set_template_parameter('TS_DETAILS_ONT', $ts_ont);
    $self->set_template_parameter('TS_DETAILS_GAF', $ts_gaf);

  }else{
    $self->set_template_parameter('TS_DETAILS_P', 0);
  }

  ## Page settings.
  $self->set_template_parameter('page_name', 'load_details');
  $self->set_template_parameter('page_title', 'AmiGO 2: Load Details');
  #$self->set_template_parameter('content_title', 'Load Details');
  $self->set_template_parameter('content_title',
				'Current instance load information');

  ## Get Galaxy, and add a variable for it in the page.
  $self->set_template_parameter('GO_GALAXY',
				$self->{CORE}->amigo_env('AMIGO_PUBLIC_GALAXY_URL'));

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      #'com.jquery.tablesorter',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'com.jquery.tablesorter',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('LoadDetails.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'LoadDetailsInit();'
     ],
     content =>
     [
      'pages/load_details.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}

## This is just a very thin pass-through client.
## TODO/BUG: not accepting "inline" parameter yet...
sub mode_visualize {

  my $self = shift;
  my $output = '';

  ##
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('visualize');
  my $format = $params->{format};
  my $input_term_data_type = $params->{term_data_type};
  my $input_term_data = $params->{term_data};

  ## Cleanse input data of newlines.
  $input_term_data =~ s/\n/ /gso;

  ## If there is no incoming data, display the "client" page.
  ## Otherwise, forward to render app.
  if( ! defined $input_term_data ){

    ##
    $self->set_template_parameter('page_name', 'visualize');
    $self->set_template_parameter('amigo_mode', 'visualize');
    $self->set_template_parameter('page_title', 'AmiGO 2: Visualize');
    $self->set_template_parameter('content_title',
				  'Visualize an Arbitrary GO Graph');
    my $prep =
      {
       css_library =>
       [
	#'standard',
	'com.bootstrap',
	'com.jquery.jqamigo.custom',
	'amigo',
	'bbop'
       ],
       javascript_library =>
       [
	'com.jquery',
	'com.bootstrap',
	'com.jquery-ui',
	'bbop',
	'amigo'
       ],
       javascript =>
       [
	$self->{JS}->get_lib('GeneralSearchForwarding.js'),
       ],
       javascript_init =>
       [
	'GeneralSearchForwardingInit();'
       ],
       content =>
       [
	'pages/visualize.tmpl']
      };
    $self->add_template_bulk($prep);
    $output = $self->generate_template_page_with();

  }else{

    ## Check to see if this JSON is even parsable...that's really all
    ## that we're doing here.
    if( $input_term_data_type eq 'json' ){
      if( ! $self->json_parsable_p($input_term_data) ){
	my $str = 'Your JSON was not formatted correctly, please go back and retry. Look at the <a href="http://wiki.geneontology.org/index.php/AmiGO_Manual:_Visualize">advanced format</a> documentation for more details.';
	return $self->mode_fatal($str);
      }
    }

    ## TODO: Until I can think of something better...
    if( $format eq 'navi' ){

      ## BETA: Just try and squeeze out whatever I can.
      my $in_terms = $self->{CORE}->clean_term_list($input_term_data);
      my $jump = $self->{CORE}->get_interlink({mode=>'layers_graph',
				       arg => {
					       terms => $in_terms,
					      }});
      return $self->redirect($jump, '302 Found');
    }else{
      my $jump = $self->{CORE}->get_interlink({mode=>'visualize',
				       #optional => {url_safe=>1, html_safe=>0},
				       #optional => {html_safe=>0},
				       arg => {
					       format => $format,
					       data_type =>
					       $input_term_data_type,
					       data => $input_term_data,
					      }});
      #$self->{CORE}->kvetch("Jumping to: " . $jump);
      ##
      #$output = $jump;
      return $self->redirect($jump, '302 Found');
    }
  }

  return $output;
}

## This is just a very thin pass-through client.
## TODO/BUG: not accepting "inline" parameter yet...
sub mode_visualize_freeform {

  my $self = shift;
  my $output = '';

  ##
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('visualize_freeform');
  my $format = $params->{format};
  my $input_term_data = $params->{term_data};
  my $input_graph_data = $params->{graph_data};

  ## Cleanse input data of newlines.
  $input_term_data =~ s/\n/ /gso;
  $input_graph_data =~ s/\n/ /gso;

  ## If there is no incoming graph data, display the "client" page.
  ## Otherwise, forward to render app.
  if( ! defined $input_graph_data ){

    ##
    $self->set_template_parameter('page_name', 'visualize_freeform');
    $self->set_template_parameter('amigo_mode', 'visualize_freeform');
    $self->set_template_parameter('page_title', 'AmiGO 2: Visualize Freeform');
    $self->set_template_parameter('content_title',
				  'Visualize an Arbitrary Graph');
    my $prep =
      {
       css_library =>
       [
	#'standard',
	'com.bootstrap',
	'com.jquery.jqamigo.custom',
	'amigo',
	'bbop'
       ],
       javascript_library =>
       [
	'com.jquery',
	'com.bootstrap',
	'com.jquery-ui',
	'bbop',
	'amigo'
       ],
       javascript =>
       [
	$self->{JS}->get_lib('GeneralSearchForwarding.js'),
       ],
       javascript_init =>
       [
	'GeneralSearchForwardingInit();'
       ],
       content =>
       [
	'pages/visualize_freeform.tmpl']
      };
    $self->add_template_bulk($prep);
    $output = $self->generate_template_page_with();

  }else{

    ## Check to see if the graph JSON is even parsable.
    if( $input_graph_data ){
      if( ! $self->json_parsable_p($input_graph_data) ){
	my $str = 'Your graph JSON was not formatted correctly...';
	return $self->mode_fatal($str);
      }
    }

    ## The same for the term data.
    if( $input_term_data ){
      if( ! $self->json_parsable_p($input_term_data) ){
	my $str = 'Your term JSON was not formatted correctly...';
	return $self->mode_fatal($str);
      }
    }

    my $jump = $self->{CORE}->get_interlink({mode=>'visualize_freeform',
				       #optional => {url_safe=>1, html_safe=>0},
				       #optional => {html_safe=>0},
					     arg => {
						     format => $format,
						     term_data => $input_term_data,
						     graph_data => $input_graph_data,
						    }});
    #$self->{CORE}->kvetch("Jumping to: " . $jump);
    ##
    #$output = $jump;
    return $self->redirect($jump, '302 Found');
  }

  return $output;
}


# ## A committed client based on the jQuery libraries and GOlr. The
# ## future.
# sub mode_live_search {

#   my $self = shift;

#   ## Pull out the bookmark parameter.
#   my $i = AmiGO::WebApp::Input->new();
#   my $params = $i->input_profile('live_search');
#   ## Normal incoming args.
#   my $bookmark = $params->{bookmark} || '';
#   my $golr_class = $params->{golr_class} || '';
#   my $query = $params->{query} || '';

#   ## Try and come to terms with Galaxy.
#   my($in_galaxy, $galaxy_external_p) = $i->comprehend_galaxy();
#   $self->galaxy_settings($in_galaxy, $galaxy_external_p);

#   ## If it is defined, try to decode it into something useful that we
#   ## can pass in as javascript.
#   if( $bookmark ){
#     # $bookmark = $self->{JS}->make_js($bookmark);
#     $bookmark =~ s/\"/\\\"/g;
#   }
#   $self->{CORE}->kvetch('bookmark: ' . $bookmark || '???');

#   ## Page settings.
#   $self->set_template_parameter('STANDARD_CSS', 'no');
#   $self->set_template_parameter('page_title', 'AmiGO 2: Search');
#   $self->set_template_parameter('page_name', 'live_search');
#   $self->set_template_parameter('content_title', 'Search');

#   ## Grab resources we want.
#   $self->set_template_parameter('STAR_IMAGE',
# 				$self->{CORE}->get_image_resource('star'));

#   ## Get the layout info to describe which tabs should be generated.
#   my $stinfo = $self->{CORE}->get_amigo_layout('AMIGO_LAYOUT_SEARCH');
#   $self->set_template_parameter('search_tab_info', $stinfo);
#   ## Pick the first to be the default. Technically, this is optional
#   ## since the JS will eventually fall back to just picking the first
#   ## defined class.
#   ## However, if we were kicked in from the landing page, we might
#   ## already have this information.
#   my $gc = $golr_class || $$stinfo[0]->{id};
#   $self->set_template_parameter('starting_golr_class', $gc);

#   ## Our AmiGO services CSS.
#   my $prep =
#     {
#      css_library =>
#      [
#       'standard',
#       #'com.jquery.redmond.custom',
#       'com.jquery.jqamigo.custom',
#      ],
#      javascript_library =>
#      [
#       'com.jquery',
#       'com.jquery-ui',
#       'bbop',
#       'amigo'
#      ],
#      javascript =>
#      [
#       $self->{JS}->make_var('global_live_search_bookmark', $bookmark),
#       $self->{JS}->make_var('global_live_search_query', $query),
#       #$self->{JS}->make_var('global_live_search_golr_class', $golr_class),
#       $self->{JS}->get_lib('GeneralSearchForwarding.js'),
#       $self->{JS}->get_lib('LiveSearchGOlr.js')
#      ],
#      javascript_init =>
#      [
#       'GeneralSearchForwardingInit();',
#       'LiveSearchGOlrInit();'
#      ],
#      content =>
#      [
#       'pages/live_search_golr.tmpl'
#      ]
#     };
#   $self->add_template_bulk($prep);

#   return $self->generate_template_page();
# }


## A committed client based on the jQuery libraries and GOlr. The
## future.
sub mode_search {

  my $self = shift;

  ## Pull out the bookmark parameter.
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('live_search');
  ## Deal with the different types of dispatch we might be facing.
  $params->{personality} = $self->param('personality')
    if ! $params->{personality} && $self->param('personality');
  ## Normal incoming args.
  my $bookmark = $params->{bookmark} || '';
  my $query = $params->{query} || '';

  ## BUG/TODO: Let people know about the bug.
  if( $query && $query ne '' ){
    $self->add_mq('warning', 'Please be aware the this page is affected by <strong><a href="https://github.com/kltm/amigo/issues/44">bug #44</a></strong>.');
  }

  ## Try and come to terms with Galaxy.
  my($in_galaxy, $galaxy_external_p) = $i->comprehend_galaxy();
  $self->galaxy_settings($in_galaxy, $galaxy_external_p);

  ## If it is defined, try to decode it into something useful that we
  ## can pass in as javascript.
  if( $bookmark ){
    # $bookmark = $self->{JS}->make_js($bookmark);
    $bookmark =~ s/\"/\\\"/g;
  }
  $self->{CORE}->kvetch('bookmark: ' . $bookmark || '???');

  ## Page settings.
  #$self->set_template_parameter('STANDARD_CSS', 'no');
  $self->set_template_parameter('page_title', 'AmiGO 2: Search');
  $self->set_template_parameter('page_name', 'live_search');
  $self->set_template_parameter('content_title', 'Search');

  ## Grab resources we want.
  $self->set_template_parameter('STAR_IMAGE',
				$self->{CORE}->get_image_resource('star'));

  ## Make sure the personality is in our known set if it's even
  ## defined.
  my $personality = $params->{personality} || '';
  my $personality_name = 'n/a';
  my $personality_desc = 'No description.';
  if( $personality ){

    ## Get the layout info to describe which personalities are
    ## available.
    my $stinfo = $self->{CORE}->get_amigo_layout('AMIGO_LAYOUT_SEARCH');

    ## Check that it is in our search set.
    my $allowed_personality = 0;
    foreach my $sti (@$stinfo){
      my $stid = $sti->{id};
      if( $personality eq $stid ){
	$allowed_personality = 1;
	$personality_name = $sti->{display_name};
	$personality_desc = $sti->{description};
	last;
      }
    }

    ## If not, kick out to error.
    if( ! $allowed_personality ){
      $self->set_template_parameter('content_title', '');
      #$self->set_template_parameter('STANDARD_CSS', 'yes');
      return $self->mode_not_found($personality, 'search personality');
    }
  }else{
    ## No incoming personality.
    return $self->mode_not_found('undefined', 'search personality');
  }

  ## Set personality for template, and later JS var.
  $self->set_template_parameter('personality', $personality);
  $self->set_template_parameter('content_subtitle', $personality_name);
  $self->set_template_parameter('personality_name', $personality_name);
  $self->set_template_parameter('personality_description', $personality_desc);

  # ## Temporary test of new template system based on BS3.
  # my $template_system = $self->template_set() || die 'no template system set';
  # if( $template_system && $template_system eq 'bs3' ){
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->make_var('global_live_search_bookmark', $bookmark),
      $self->{JS}->make_var('global_live_search_query', $query),
      $self->{JS}->make_var('global_live_search_personality', $personality),
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('LiveSearchGOlr.js')
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'LiveSearchGOlrInit();'
     ],
     content =>
     [
      'pages/live_search_golr.tmpl'
     ]
    };
  $self->add_template_bulk($prep);
  #$self->add_mq('warning', "Remove this test when this is YELLOW!");
  #return $self->generate_template_page_with();
  # }else{
  #   my $prep =
  #     {
  #      css_library =>
  #      [
  # 	'standard',
  # 	#'com.jquery.redmond.custom',
  # 	'com.jquery.jqamigo.custom',
  #      ],
  #      javascript_library =>
  #      [
  # 	'com.jquery',
  # 	'com.jquery-ui',
  # 	'bbop',
  # 	'amigo'
  #      ],
  #      javascript =>
  #      [
  # 	$self->{JS}->make_var('global_live_search_bookmark', $bookmark),
  # 	$self->{JS}->make_var('global_live_search_query', $query),
  # 	$self->{JS}->make_var('global_live_search_personality', $personality),
  # 	$self->{JS}->get_lib('GeneralSearchForwarding.js'),
  # 	$self->{JS}->get_lib('LiveSearchGOlr.js')
  #      ],
  #      javascript_init =>
  #      [
  # 	'GeneralSearchForwardingInit();',
  # 	'LiveSearchGOlrInit();'
  #      ],
  #      content =>
  #      [
  # 	'pages/live_search_golr.tmpl'
  #      ]
  #     };
  #   $self->add_template_bulk($prep);
  #   return $self->generate_template_page();
  # }

  #return $self->generate_template_page_with({search=>1});
  return $self->generate_template_page_with();
}


## Experimental try at the term details page, in perl, backed by the
## solr index.
sub mode_term_details {

  my $self = shift;

  ##
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('term');
  ## Deal with the different types of dispatch we might be facing.
  $params->{term} = $self->param('term')
    if ! $params->{term} && $self->param('term');
  $self->{CORE}->kvetch(Dumper($params));
  my $input_term_id = $params->{term};

  ## Input sanity check.
  if( ! $input_term_id ){
    return $self->mode_fatal("No term acc input argument.");
  }

  ## Experimental bookmark capture.
  my $pin = $params->{pin} || '';
  if( $pin ){
    $pin =~ s/\"/\\\"/g;
  }
  $self->{CORE}->kvetch('incoming pin: ' . $pin || '<none>');

  ###
  ### Get full term info.
  ###

  ## Get the data from the store.
  my $term_worker = AmiGO::Worker::GOlr::Term->new($input_term_id);
  my $term_info_hash = $term_worker->get_info();

  ## First make sure that things are defined.
  if( ! defined($term_info_hash) ||
      $self->{CORE}->empty_hash_p($term_info_hash) ||
      ! defined($term_info_hash->{$input_term_id}) ){
    return $self->mode_not_found($input_term_id, 'term');
  }

  $self->{CORE}->kvetch('solr docs: ' . Dumper($term_info_hash));

  ## Should just be one now, yeah?
  #my $foo = (keys %$term_info_hash)[0];
  #$self->{CORE}->kvetch('$term_info: ' . Dumper($term_info->{$foo}));
  $self->set_template_parameter('TERM_INFO',
				$term_info_hash->{$input_term_id});

  ## First switch on internal term vs. external.
  my $is_term_acc_p = $self->{CORE}->is_term_acc_p($input_term_id);
  my $acc_list_for_gpc_info = [];
  my $input_term_id_list = [];
  my $exotic_p = undef;
  if( $is_term_acc_p ){

    $self->{CORE}->kvetch('Looks like a term acc: ' . $input_term_id);
    $exotic_p = 0;

  }else{

    ## Looks exotic.
    $self->{CORE}->kvetch('Looks like an exotic acc: ' . $input_term_id);
    $exotic_p = 1;

    ## Let's try and get a link for the exotic ID.
    my($edb, $eid) = $self->{CORE}->split_gene_product_acc($input_term_id);
    my $exotic_link = $self->{CORE}->database_link($edb, $eid) || '';

    ## Try to make the message link out.
    my $exotic_term = '';
    if( $exotic_link ){
      $exotic_term = '<a href="' .
	$exotic_link . '" title="Go to the homepage for ' .
	  $input_term_id . '">' .
	    $input_term_id . '</a>';
    }else{
      $exotic_term = $input_term_id;
    }

    ## Add a nice message.
    $self->add_mq('warning', "The term $exotic_term" .
		  ' is not an internal term,' .
		  ' but likely comes from an external resource.' .
		  ' For full information on this term,' .
		  ' please refer to the originating resource.');
  }
  $self->set_template_parameter('EXOTIC_P', $exotic_p);

  ###
  ### Get neighborhood below term.
  ###

  ## Note: won't be included in subset case (too messy), so don't
  ## push.
  #if( $is_term_acc_p ){
    my $sorted_child_chunks =
      $term_worker->get_child_info_for($input_term_id);
    #$self->{CORE}->kvetch('scc: ' . Dumper($sorted_child_chunks));
    foreach my $cinfo (@$sorted_child_chunks){ 
      push @$acc_list_for_gpc_info, $cinfo->{acc};
    }
    $self->set_template_parameter('CHILD_CHUNKS', $sorted_child_chunks);
  #}

  ###
  ### Get term ancestor information.
  ###

  # #$self->{CORE}->kvetch("input_term_id_list" . Dumper($input_term_id_list));

  ##
  my $anc_info = undef;
  if( $is_term_acc_p ){
    $anc_info = $term_worker->get_ancestor_info($input_term_id);
  }else{
    ## We want to include self in ancestors in this case.
    $anc_info =
      $term_worker->get_ancestor_info($input_term_id, {reflexive=>1});
  }
  $self->set_template_parameter('MAX_DEPTH', $anc_info->{max_depth});
  $self->set_template_parameter('MAX_DISPLACEMENT',
  				$anc_info->{max_displacement});
  $self->set_template_parameter('PARENT_CHUNKS_BY_DEPTH',
  				$anc_info->{parent_chunks_by_depth});
  push @$acc_list_for_gpc_info, @{$anc_info->{seen_acc_list}};

  ## Bridge variables from old system.
  #$self->set_template_parameter('cgi', 'term-details');
  $self->set_template_parameter('cgi', 'browse');
  $self->set_template_parameter('vbridge', 'term=' . $input_term_id);

  ###
  ### External links.
  ###

  $self->set_template_parameter('VIZ_STATIC_LINK',
				$self->{CORE}->get_interlink({mode =>
							      'visualize',
							      arg =>
							      {data =>
							       $input_term_id,
							       format =>
							       'png'}}));
  $self->set_template_parameter('VIZ_DYNAMIC_LINK',
				$self->{CORE}->get_interlink({mode =>
							      'visualize',
							      arg =>
							      {data =>
							       $input_term_id,
							       format =>
							       'svg'}}));
  $self->set_template_parameter('NAVIGATION_LINK',
				$self->{CORE}->get_interlink({mode =>
							      'layers_graph',
							      arg =>
							      {terms =>
							       $input_term_id}}));

  $self->set_template_parameter('OLSVIS_GO_LINK',
				$self->{CORE}->get_interlink({mode=>'olsvis_go',
							      arg =>
							      {term =>
							       $input_term_id},
							      optional =>
							      {'full' => 0}}));


  $self->set_template_parameter('VIZ_QUICKGO_LINK',
				$self->{CORE}->get_interlink({mode=>'visualize_simple',
							      arg =>
							      {engine=>'quickgo',
							       term =>
							       $input_term_id}}));

  ## Only need QuickGO for internal terms.
  if( ! $exotic_p ){
    my $qg_term = AmiGO::External::QuickGO::Term->new();
    $self->set_template_parameter('QUICKGO_TERM_LINK',
				  $qg_term->get_term_link($input_term_id));

    $self->set_template_parameter('QUICKGO_ENGINE_P',
				  $self->{CORE}->amigo_env('AMIGO_GO_ONLY_GRAPHICS'));
  }

  ###
  ### GONUTs
  ###

  ## TODO: I'd like to be able to set this up for some trivial GONUTS
  ## kappa tests.
  ## GONuts query.
  ## Cutoff a year ago (in seconds).
  ## TODO: we should compact this into a worker now that we have a chance.
  my $gonuts = AmiGO::External::XML::GONUTS->new({cutoff_time => 31536000});
  my $answer_p = $gonuts->query_term($input_term_id);
  $self->set_template_parameter('GONUTS_SUCCESS', 0);
  if( $answer_p ){
    $self->set_template_parameter('GONUTS_SUCCESS', 1);
    $self->set_template_parameter('GONUTS_TOTAL_COUNT',
				  $gonuts->get_total_count());
    $self->set_template_parameter('GONUTS_RECENT_COUNT',
				  $gonuts->get_recent_count());
    $self->set_template_parameter('GONUTS_PAGE_TITLE',
				  $gonuts->get_page_title());
    $self->set_template_parameter('GONUTS_PAGE_URL',
				  $gonuts->get_page_url());
    $self->set_template_parameter('GONUTS_DATE_STRING',
				  $gonuts->get_date_string());

      # ## DEBUG
      # $gonuts->kvetch('GONUTS: got an answer:');
      # $gonuts->kvetch("\t" . $gonuts->get_total_count());
      # $gonuts->kvetch("\t" . $gonuts->get_recent_count());
      # $gonuts->kvetch("\t" . $gonuts->get_page_title());
      # $gonuts->kvetch("\t" . $gonuts->get_page_url());
  }

  ###
  ### Standard setup.
  ### TODO: We see this a lot--should this be abstracted out too? No?
  ###

  ## Page settings.
  $self->set_template_parameter('page_name', 'term');
  $self->set_template_parameter('page_title',
				'AmiGO 2: Term Details for "' .
				$term_info_hash->{$input_term_id}{'name'} .
				'" (' .	$input_term_id . ')');
  $self->set_template_parameter('content_title',
				$term_info_hash->{$input_term_id}{'name'});

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'com.jquery.tablesorter',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'com.jquery.tablesorter',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('TermDetails.js'),
      # $self->{JS}->make_var('global_count_data', $gpc_info),
      # $self->{JS}->make_var('global_rand_to_acc', $rand_to_acc),
      # $self->{JS}->make_var('global_acc_to_rand', $acc_to_rand),
      $self->{JS}->make_var('global_acc', $input_term_id),
      $self->{JS}->make_var('global_pin', $pin),
      $self->{JS}->make_var('global_label',
			    $term_info_hash->{$input_term_id}{'name'})
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'TermDetailsInit();'
     ],
     content =>
     [
      'pages/term_details.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


## Experimental try at the gp details page, in perl, backed by the
## solr index.
sub mode_gene_product_details {

  my $self = shift;

  ##
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('gp');
  ## Deal with the different types of dispatch we might be facing.
  $params->{gp} = $self->param('gp')
    if ! $params->{gp} && $self->param('gp');
  my $input_gp_id = $params->{gp};

  ## Input sanity check.
  if( ! $input_gp_id ){
    return $self->mode_fatal("No input gene product acc argument.");
  }

  ###
  ### Get full gp info.
  ###

  ## Get the data from the store.
  my $gp_worker = AmiGO::Worker::GOlr::GeneProduct->new($input_gp_id);
  my $gp_info_hash = $gp_worker->get_info();

  ## First make sure that things are defined.
  if( ! defined($gp_info_hash) ||
      $self->{CORE}->empty_hash_p($gp_info_hash) ||
      ! defined($gp_info_hash->{$input_gp_id}) ){
    return $self->mode_not_found($input_gp_id, 'gene product');
  }

  $self->{CORE}->kvetch('solr docs: ' . Dumper($gp_info_hash));
  $self->set_template_parameter('GP_INFO', $gp_info_hash->{$input_gp_id});

  ## PANTHER info if there.
  my $pgraph = $gp_info_hash->{$input_gp_id}{'phylo_graph'};
  if( $pgraph ){
    $self->set_template_parameter('PHYLO_TREE_LINK',
				  $self->{CORE}->get_interlink({mode=>
								'phylo_graph',
								'arg'=>
								{'gp'=>
								 $input_gp_id}}));
  }

  ###
  ### TODO: pull in additional annotation, etc. info.
  ###

  ###
  ### Standard setup.
  ###

  ## Page settings.
  $self->set_template_parameter('page_name', 'gene_product');
  $self->set_template_parameter('page_title',
				'AmiGO 2: Gene Product Details for ' .
				$input_gp_id);
  ## Figure out the best title we can.
  my $best_title = $input_gp_id; # start with the worst as a default
  if ( $gp_info_hash->{$input_gp_id}{'name'} ){
    $best_title = $gp_info_hash->{$input_gp_id}{'name'};
  }elsif( $gp_info_hash->{$input_gp_id}{'label'} ){
    $best_title = $gp_info_hash->{$input_gp_id}{'label'};
  }
  $self->set_template_parameter('content_title', $best_title);

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('GPDetails.js'),
      # $self->{JS}->make_var('global_count_data', $gpc_info),
      # $self->{JS}->make_var('global_rand_to_acc', $rand_to_acc),
      # $self->{JS}->make_var('global_acc_to_rand', $acc_to_rand),
      $self->{JS}->make_var('global_acc', $input_gp_id)
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'GPDetailsInit();'
     ],
     content =>
     [
      'pages/gene_product_details.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


## Complex annotation/annotation group/annotation unit information.
sub mode_complex_annotation_details {

  my $self = shift;

  ##
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('complex_annotation');
  ## Deal with the different types of dispatch we might be facing.
  # $params->{annotation_group} = $self->param('annotation_group')
  #   if ! $params->{annotation_group} && $self->param('annotation_group');
  # my $input_annotation_group_id = $params->{annotation_group};
  $params->{complex_annotation} = $self->param('complex_annotation')
    if ! $params->{complex_annotation} && $self->param('complex_annotation');
  my $input_id = $params->{complex_annotation};

  ## Input sanity check.
  if( ! $input_id ){
    return $self->mode_fatal("No input complex annotation argument.");
  }

  ## Warn people away for now.
  $self->add_mq('warning',
		'This page is considered <strong>ALPHA</strong> software.');

  ###
  ### Get full info.
  ###

  ## Get the data from the store.
  #AmiGO::Worker::GOlr::ComplexAnnotationUnit->new($input_id);
  my $ca_worker =

    AmiGO::Worker::GOlr::ComplexAnnotationGroup->new($input_id);
  my $ca_info_hash = $ca_worker->get_info();

  ## First make sure that things are defined.
  if( ! defined($ca_info_hash) ||
      $self->{CORE}->empty_hash_p($ca_info_hash) ||
      ! defined($ca_info_hash->{$input_id}) ){
    return $self->mode_not_found($input_id,
				 'complex annotation');
  }

  $self->{CORE}->kvetch('solr docs: ' . Dumper($ca_info_hash));
  $self->set_template_parameter('CA_INFO',
				$ca_info_hash->{$input_id});

  ## Will only need to link through the visualizer,
  my $vlink =
    $self->{CORE}->get_interlink({mode => 'visualize_complex_annotation',
				  arg => {complex_annotation =>
					  $input_id}});
  $self->set_template_parameter('VIZ_STATIC_LINK', $vlink);

  ###
  ### Standard setup.
  ###

  ## Page settings.
  $self->set_template_parameter('page_name', 'complex_annotation');
  $self->set_template_parameter('page_title',
				'AmiGO 2: Complex Annotation Details for ' .
				$input_id);

  ## Figure out the best title we can.
  my $best_title = $input_id; # start with the worst
  if ( $ca_info_hash->{$input_id}{'annotation_group_label'} ){
    $best_title =
      $ca_info_hash->{$input_id}{'annotation_group_label'};
  }elsif( $ca_info_hash->{$input_id}{'annotation_group'} ){
    $best_title =
      $ca_info_hash->{$input_id}{'annotation_group'};
  }
  $self->set_template_parameter('content_title', $best_title);

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      'com.bootstrap',
      'com.jquery-ui',
      'bbop',
      'amigo'
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      #$self->{JS}->get_lib('GPDetails.js'),
      # $self->{JS}->make_var('global_count_data', $gpc_info),
      # $self->{JS}->make_var('global_rand_to_acc', $rand_to_acc),
      # $self->{JS}->make_var('global_acc_to_rand', $acc_to_rand),
      $self->{JS}->make_var('global_acc', $input_id)
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      #'GPDetailsInit();'
     ],
     content =>
     [
      'pages/complex_annotation_details.tmpl'
     ]
    };
  $self->add_template_bulk($prep);

  return $self->generate_template_page_with();
}


## Very similar at this point to the gp details page, but instead
## we're just trying to load the phylo tree.
sub mode_phylo_graph {

  my $self = shift;

  ##
  my $i = AmiGO::WebApp::Input->new();
  my $params = $i->input_profile('family');
  ## Deal with the different types of dispatch we might be facing.
  $params->{family} = $self->param('family')
    if ! $params->{family} && $self->param('family');
  my $input_family_id = $params->{family} || '';

  ## Input sanity check.
  if( ! $input_family_id ){
    $self->add_mq('warning', "Family ID argument not found. " .
		  "Will use <strong>demo mode</strong> instead.");
  #}else{
  }

  ###
  ### Standard setup.
  ###

  ## Page seetings.
  my $global_family = undef;
  if( $input_family_id ){
    $self->set_template_parameter('page_title',
				  'AmiGO 2:  Family tree for ' .
				  $input_family_id);
    $self->set_template_parameter('content_title', $input_family_id);
    $self->set_template_parameter('demo_mode', 'false');
    $global_family = $input_family_id;
  }else{
    $self->set_template_parameter('page_title', 'AmiGO 2:  Family tree demo');
    $self->set_template_parameter('content_title', 'Family tree demo');
    $self->set_template_parameter('demo_mode', 'true');
    $global_family = undef;
  }

  ## Our AmiGO services CSS.
  my $prep =
    {
     css_library =>
     [
      #'standard',
      #'com.bootstrap',
      'com.jquery.jqamigo.custom',
      'amigo',
      'bbop'
     ],
     javascript_library =>
     [
      'com.jquery',
      #'com.bootstrap',
      'com.jquery-ui',
      #'com.raphael',
      #'com.raphael.graffle',
      'bbop',
      'amigo'
      #'bbop.model',
      #'bbop.model.tree',
      #'bbop.graph.render.phylo',
     ],
     javascript =>
     [
      $self->{JS}->get_lib('GeneralSearchForwarding.js'),
      $self->{JS}->get_lib('PhyloGraph.js'),
      $self->{JS}->make_var('global_family', $global_family)
     ],
     javascript_init =>
     [
      'GeneralSearchForwardingInit();',
      'PhyloGraphInit();'
     ],
     content =>
     [
      'pages/phylo_graph.tmpl'
     ]
   };
  $self->add_template_bulk($prep);

  ## Initialize javascript app.
  #$self->add_template_javascript($self->{JS}->get_lib('PANTHERTree.js'));
  # $self->add_template_javascript($self->{JS}->initializer_jquery('PT();'));

  # $self->add_template_content('pages/phylo_graph.tmpl');

  ## Nothing for now.
  return $self->generate_template_page_with({
					     header=>0,
					     footer=>0,
					    });
}



1;
