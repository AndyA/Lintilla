package Lintilla::Site;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome;
use Lintilla::Data::Static;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use Lintilla::TT::Extensions;
use Path::Class;

our $VERSION = '0.1';

use constant BOILERPLATE => qw( services years decades decade_years );

sub db() { Lintilla::DB::Genome->new( dbh => database ) }

my $STATIC = Lintilla::Data::Static->new(
  store => dir( setting('appdir'), 'data' ) );

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

get '/' => sub {
  my $db = db;
  template 'index',
   {$db->gather(BOILERPLATE),
    title    => 'BBC Genome',
    stations => $STATIC->get('stations'),
    stash    => sub { $db->stash(shift) },
   };
};

get '/schedules/:service' => sub {
  delete request->env->{SCRIPT_NAME}; # don't include disptch.fcgi in URI
  redirect '/schedules/'
   . param('service') . '/'
   . db->service_start_date( param('service') );
};

get '/schedules/:service/:date' => sub {
  my $db = db;
  template 'schedule', { $db->gather(BOILERPLATE), };
};

get '/search' => sub {
  my $q = param('q');
  template 'index',
   {q  => $q,
    ds => request->uri_for( '/data/search/:size/:start', { q => $q } ),
   };
};

true;
