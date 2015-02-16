package Lintilla::Site;

use v5.10;
use Dancer ':syntax';

use Barlesque::Client;
use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Edit;
use Lintilla::DB::Genome;
use Lintilla::Data::Static;
use Lintilla::Personality;
use Lintilla::Site::Admin;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use Lintilla::Site::Debug;
use Lintilla::Site::Diagnostic;
use Lintilla::Site::Edit;
use Lintilla::Site::Labs;
use Lintilla::Site::Sync;
use Lintilla::TT::Context;
use Lintilla::TT::Extensions;
use Path::Class;
use URI;

our $VERSION = '0.1';

no if $] >= 5.018, warnings => "experimental::smartmatch";

use constant BOILERPLATE =>
 qw( services years decades decade_years month_names short_month_names );

use constant URL_SHRINKER =>
 'http://www.bbc.co.uk/modules/share/service/shrink';

sub db() {
  Lintilla::DB::Genome->new(
    dbh   => database,
    infax => config->{infax_link} ? 1 : 0
  );
}

sub resources {
  return state $res ||= Lintilla::Tools::Enqueue->new(
    map => {
      css => {
        fa        => { url => '/css/font-awesome/css/font-awesome.min.css' },
        jquery_ui => { url => '/css/jquery-ui.min.css' },
      },
      js => {
        jquery    => { url => '/js/jquery-1.11.1.min.js' },
        jquery_ui => {
          url      => '/js/jquery-ui.min.js',
          requires => ['css.jquery_ui', 'js.jquery']
        },
        spin => { url => '/js/spin.min.js' },
      } }
  );
}

my $STATIC = Lintilla::Data::Static->new(
  store => dir( setting('appdir'), 'data' ) );

if ( config->{magic_context} ) {
  $Template::Config::CONTEXT = 'Lintilla::TT::Context';
}

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub is_tls {
  my $tls = request->env->{HTTP_X_TLS} // 'no';
  return $tls eq 'yes';
}

sub barlesque {
  Barlesque::Client->new(
    blq_doctype             => 'html5',
    blq_link_prefix         => 'http://www.bbc.co.uk',
    blq_version             => 4,
    blq_nedstat_countername => 'genome.test.page',
    blq_nedstat             => 1,
    ( is_tls() ? ( blq_https => 1 ) : () )
  );
}

sub clean_word {
  ( my $w = shift ) =~ s/\W//g;
  return 'unknown' unless length $w;
  return $w;
}

sub echo_key {
  my @path = @_;
  my $pe   = vars->{personality};
  return join '.', map { clean_word($_) } 'genome', $pe->personality,
   @path, 'page';
}

sub boilerplate($) {
  my $db   = shift;
  my $dbe  = Lintilla::DB::Genome::Edit->new( dbh => $db->dbh );
  my $srch = Lintilla::DB::Genome::Search->new;
  my $pe   = vars->{personality};
  return (
    $db->gather(BOILERPLATE),
    barlesque   => barlesque->parts,
    static_base => is_tls()
    ? 'https://static.bbc.co.uk'
    : 'http://static.bbci.co.uk',
    visibility    => $pe->personality,
    change_count  => $dbe->change_count,
    stash         => sub { $db->stash(shift) },
    timelist      => sub { $srch->timelist },
    title         => $db->page_title,
    stations      => $STATIC->get('stations'),
    form          => $srch->form,
    switchview    => $pe->switcher,
    share_stash   => $db->share_stash,
    show_external => !config->{disable_external},
    infax_link    => !!config->{infax_link},
    debug_script  => config->{debug_script},
    echo_key      => echo_key(),
  );
}

sub self {
  return request->scheme . '://' . request->host . request->request_uri;
}

hook 'before' => sub {
  my $vis = request->env->{HTTP_X_VISIBILITY} // 'external';
  my $rules = "switcher-$vis";
  var personality => Lintilla::Personality->new(
    url   => self(),
    rules => $STATIC->get($rules)
  );
};

get '/' => sub {
  template 'index', { boilerplate db };
};

sub safe_service_defaults {
  my ( $db, $service ) = @_;
  my @dflt = db->service_defaults( param('service') );
  return '/schedules/missing' unless @dflt;
  return join( '/', '/schedules', $service, @dflt );
}

get '/schedules/missing' => sub {
  my $db = db;
  template 'schedule',
   {boilerplate $db,
    missing  => 1,
    title    => $db->page_title('Listing Unavailable'),
    echo_key => echo_key('missing'),
   };
};

get '/schedules/:service/near/:date' => sub {
  delete request->env->{SCRIPT_NAME};
  redirect join '/', '/schedules',
   db->service_near( param('service'), param('date') );
};

get '/schedules/:service' => sub {
  delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
  redirect safe_service_defaults( db, param('service') );
};

get '/schedules/:service/:date' => sub {
  my $db = db;
  my @dflt = $db->service_defaults( param('service'), param('date') );
  if ( @dflt > 1 ) {
    delete request->env->{SCRIPT_NAME};
    redirect join '/', '/schedules', param('service'), @dflt;
    return;
  }
  template 'schedule',
   {boilerplate $db,
    echo_key => echo_key( 'schedule', param('service') ),
    $db->listing_for_schedule( param('service'), param('date') ),
   };
};

get '/schedules/:service/:outlet/:date' => sub {
  my $db = db;
  template 'schedule',
   {boilerplate $db,
    echo_key => echo_key( 'schedule', param('service') ),
    $db->listing_for_schedule(
      param('service'), param('outlet'), param('date')
    ),
   };
};

get '/years/:year' => sub {
  my $db = db;
  pass unless param('year') =~ /^\d+$/;
  template 'year',
   {boilerplate $db,
    echo_key => echo_key( 'year', param('year') ),
    $db->issues_for_year( param('year') ),
   };
};

get '/issues' => sub {
  my $db = db;
  template 'issues',
   {boilerplate $db,
    echo_key => echo_key('issues'),
    $db->annual_issues
   };
};

get '/search/:start/:size' => sub {
  my $db = db;
  template 'search',
   {boilerplate $db,
    echo_key => echo_key('search'),
    $db->search(params) };
};

get '/search' => sub {
  my $db = db;
  delete request->env->{SCRIPT_NAME};
  my $uri = URI->new( request->uri_for('/search/0/20') );
  $uri->query_form(params);
  redirect $uri;
};

get '/help' => sub {
  my $db = db;
  template 'help',
   {boilerplate $db,
    echo_key => echo_key('help'),
    share_stash =>
     $db->share_stash( title => 'FAQs for the BBC Genome Project' ),
    title => $db->page_title('FAQs') };
};

get '/faqs' => sub {
  my $db = db;
  template 'help',
   {boilerplate $db,
    echo_key => echo_key('faqs'),
    share_stash =>
     $db->share_stash( title => 'FAQs for the BBC Genome Project' ),
    title => $db->page_title('FAQs') };
};

get '/about' => sub {
  my $db = db;
  template 'about',
   {boilerplate $db,
    echo_key => echo_key('about'),
    share_stash =>
     $db->share_stash( title => 'About the BBC Genome Project' ),
    title => $db->page_title('About this project') };
};

get '/style-guide' => sub {
  my $db = db;
  template 'style-guide',
   {boilerplate $db,
    echo_key => echo_key('styleguide'),
    share_stash =>
     $db->share_stash( title => 'Editing Style Guide for BBC Genome' ),
    title => $db->page_title('Editing Style Guide') };
};

get qr/\/([0-9a-f]{32})/i => sub {
  my ($uuid) = splat;
  my $db     = db;
  my $thing  = $db->lookup_uuid($uuid);
  given ( $thing->{kind} ) {
    when ('issue') {
      template 'issue',
       {boilerplate $db,
        echo_key => echo_key('issue'),
        $db->issue_listing($uuid) };
    }
    when ('programme') {
      template 'programme',
       {boilerplate $db,
        echo_key => echo_key('programme'),
        $db->programme($uuid) };
    }
    default {
      pass;
    }
  }
};

# Redirect for URL shrinking

get '/modules/share/service/shrink' => sub {
  my $shrink = URI->new(URL_SHRINKER);
  $shrink->query_form(params);
  redirect $shrink;
};

# Must be last
any qr{.*} => sub {
  status 'not_found';
  template 'error404',
   {boilerplate db,
    echo_key => echo_key('404'),
    path     => request->path
   };
};

true;
