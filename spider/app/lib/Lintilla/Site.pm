package Lintilla::Site;

use v5.10;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Spider;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;

our $VERSION = '0.1';

use constant BOILERPLATE => qw( services years decades );

sub db() { Lintilla::DB::Spider->new( dbh => database ) }

get '/' => sub {
  template 'index', {};
};

get '/search' => sub {
  my $start = param('start') // 0;
  my $size  = param('size')  // 30;
  my $q     = param('q')     // '';
  template 'search',
   {page => {
      start => $start,
      size  => $size,
      q     => $q,
    },
    search => db->search( $start, $size, $q ),
   };
};

true;
