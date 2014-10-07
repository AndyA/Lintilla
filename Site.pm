package Lintilla::Site;

use v5.10;
use Dancer ':syntax';

use Barlesque::Client;
use Dancer::Plugin::Database;
use Lintilla::DB::Genome;
use Lintilla::Data::Static;
use Lintilla::Personality;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use Lintilla::Site::Debug;
use Lintilla::Site::Diagnostic;
use Lintilla::Site::Edit;
use Lintilla::Site::Labs;
use Lintilla::Site::Sync;
use Lintilla::TT::Extensions;
use Path::Class;
use URI;

our $VERSION = '0.1';

no if $] >= 5.018, warnings => "experimental::smartmatch";

use constant BOILERPLATE =>
 qw( services years decades decade_years month_names short_month_names );

sub db() { Lintilla::DB::Genome->new( dbh => database ) }

my $STATIC = Lintilla::Data::Static->new(
  store => dir( setting('appdir'), 'data' ) );

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub barlesque {
  Barlesque::Client->new(
    blq_doctype     => 'html5',
    blq_link_prefix => 'http://www.bbc.co.uk',
    blq_version     => 4,
  );
}

sub boilerplate($) {
  my $db   = shift;
  my $srch = Lintilla::DB::Genome::Search->new;
  my $pe   = vars->{personality};
  return (
    $db->gather(BOILERPLATE),
    barlesque  => barlesque->parts,
    visibility => $pe->personality,
    stash         => sub { $db->stash(shift) },
    timelist      => sub { $srch->timelist },
    title         => $db->page_title,
    stations      => $STATIC->get('stations'),
    form          => $srch->form,
    switchview    => $pe->switcher,
    show_external => !config->{disable_external},
    debug_script  => config->{debug_script},
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
    missing => 1,
    title   => $db->page_title('Listing Unavailable'),
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
    $db->listing_for_schedule( param('service'), param('date') ),
   };
};

get '/schedules/:service/:outlet/:date' => sub {
  my $db = db;
  template 'schedule',
   {boilerplate $db,
    $db->listing_for_schedule(
      param('service'), param('outlet'), param('date')
    ),
   };
};

get '/years/:year' => sub {
  my $db = db;
  template 'year',
   { boilerplate $db, $db->issues_for_year( param('year') ), };
};

get '/issues' => sub {
  my $db = db;
  template 'issues', { boilerplate $db, $db->annual_issues };
};

get '/search/:start/:size' => sub {
  my $db = db;
  template 'search', { boilerplate $db, $db->search(params) };
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
  template 'help', { boilerplate $db, title => $db->page_title('FAQs') };
};

get '/faqs' => sub {
  my $db = db;
  template 'help', { boilerplate $db, title => $db->page_title('FAQs') };
};

get '/about' => sub {
  my $db = db;
  template 'about',
   { boilerplate $db, title => $db->page_title('About this project') };
};

get qr/\/([0-9a-f]{32})/i => sub {
  my ($uuid) = splat;
  my $db     = db;
  my $thing  = $db->lookup_uuid($uuid);
  given ( $thing->{kind} ) {
    when ('issue') {
      template 'issue', { boilerplate $db, $db->issue_listing($uuid) };
    }
    when ('programme') {
      template 'programme', { boilerplate $db, $db->programme($uuid) };
    }
    default {
      pass;
    }
  }
};

# Must be last
any qr{.*} => sub {
  status 'not_found';
  template 'error404', { boilerplate db, path => request->path };
};

true;
