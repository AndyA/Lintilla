package Lintilla::Site;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;

our $VERSION = '0.1';

use constant BOILERPLATE => qw( services years decades );

sub db() { Lintilla::DB::Genome->new( dbh => database ) }

get '/' => sub {
  template 'index', { db->gather(BOILERPLATE), };
};

get '/schedules/:service' => sub {
  forward '/schedules/'
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
