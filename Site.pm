package Lintilla::Site;

use v5.10;
use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome;
use Lintilla::Data::Static;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use Lintilla::TT::Extensions;
use Path::Class;

our $VERSION = '0.1';

use constant BOILERPLATE =>
 qw( services years decades decade_years month_names );

sub db() { Lintilla::DB::Genome->new( dbh => database ) }

my $STATIC = Lintilla::Data::Static->new(
  store => dir( setting('appdir'), 'data' ) );

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub magic {
  my $db = shift;
  return (
    stash    => sub { $db->stash(shift) },
    timelist => sub {
      my $quant = shift || 15;
      my @tm = ();
      for ( my $td = 0; $td < 24 * 60; $td += $quant ) {
        push @tm, sprintf '%02d:%02d', int( $td / 60 ), $td % 60;
      }
      return @tm;
    },
  );
}

sub boilerplate($) {
  my $db = shift;
  return (
    $db->gather(BOILERPLATE),
    magic($db),
    title    => 'BBC Genome',
    stations => $STATIC->get('stations'),
    form     => Lintilla::DB::Genome::Search->new->persist,
  );
}

get '/' => sub {
  template 'index', { boilerplate db };
};

get '/schedules/:service' => sub {
  delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
  redirect join '/', '/schedules', param('service'),
   db->service_defaults( param('service') );
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

get '/help'  => sub { template 'help',  { boilerplate db } };
get '/about' => sub { template 'about', { boilerplate db } };

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
      die;
    }
  }
};

true;
