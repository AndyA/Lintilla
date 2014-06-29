package Lintilla::Site;

use v5.10;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Spider;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use List::Util qw( min max );
use URI;

our $VERSION = '0.1';

use constant PAGES => 20;

sub db() { Lintilla::DB::Spider->new( dbh => database ) }

get '/' => sub {
  template 'index', {};
};

sub search {
  my ( $start, $size, $q ) = @_;
  return {
    page => {
      start => $start,
      size  => $size,
      q     => $q,
    },
    search => db->search( $start, $size, $q ),
  };
}

sub search_link {
  my ( $start, $size, $q ) = @_;
  my $uri = URI->new('/search');
  $uri->query_form( start => $start, size => $size, q => $q );
  return $uri;
}

sub pager {
  my $stash = shift;
  my $start = $stash->{page}{start} // 0;
  my $size  = $stash->{page}{size} // 30;
  my $q     = $stash->{page}{q} // '';
  my $total = $stash->{search}{results}{total_found} // 0;

  my $page = int( $start / $size );
  my $pages = int( ( $total + $size - 1 ) / $size );

  my $first = max( 0, int( $page - PAGES / 2 ) );
  my $last = min( $first + PAGES - 1, $pages );
  my @pages = ();
  for my $pn ( $first .. $last ) {
    push @pages,
     {page => $pn + 1,
      $pn == $page ? () : ( link => search_link( $pn * $size, $size, $q ) ) };
  }

  my $pager = {
    prev => ( $page > 0 ? search_link( $start - $size, $size, $q ) : undef ),
    next => (
      $page < $pages - 1 ? search_link( $start + $size, $size, $q ) : undef
    ),
    pages => \@pages,
  };

  $stash->{page}{pager} = $pager;

  return $stash;
}

get '/search' => sub {
  my $start = param('start') // 0;
  my $size  = param('size')  // 30;
  my $q     = param('q')     // '';
  template 'search', pager( search( $start, $size, $q ) );
};

true;
