package Lintilla::Site;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;

our $VERSION = '0.1';

get '/' => sub {
  my $db = Lintilla::DB::Genome->new( dbh => database );
  template 'index', { services => $db->services };
};

get '/search' => sub {
  my $q = param('q');
  template 'index',
   {q  => $q,
    ds => request->uri_for( '/data/search/:size/:start', { q => $q } ),
   };
};

true;
