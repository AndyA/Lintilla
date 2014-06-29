package Lintilla::Site;

use v5.10;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use HTML::Parser;
use Lintilla::DB::Spider;
use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use Lintilla::Slugger;
use List::Util qw( min max );
use URI;

our $VERSION = '0.1';

use constant PAGES => 20;
use constant SLUGS => 6;

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
  my $last = min( $first + PAGES - 1, $pages - 1 );
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

sub get_title {
  my ($doc)   = @_;
  my $p       = HTML::Parser->new;
  my $intitle = 0;
  my @title;
  $p->handler(
    start => sub { $intitle++ if $_[0] eq 'title' },
    'tagname'
  );
  $p->handler(
    end => sub { $p->eof if $_[0] eq 'title' && --$intitle == 0 },
    'tagname'
  );
  $p->handler( text => sub { push @title, $_[0] if $intitle }, 'dtext' );
  $p->parse($doc);
  return join ' ', @title;
}

sub word_slugs {
  my ( $word, $text, $len ) = @_;
  while ( $text =~ /\<\Q$word\E\>/i ) {
  }
}

sub slugs {
  my ( $query, $text, $len ) = @_;
}

sub decorate {
  my $stash = shift;
  for my $rec ( @{ $stash->{search}{matches} } ) {
    $rec->{title} = get_title( $rec->{body} );
    my $iter = Lintilla::Slugger->new(
      text  => $rec->{plain},
      query => $stash->{page}{q}
    )->iterator;
    my @slugs = ();
    for ( 1 .. SLUGS ) {
      my $ext = $iter->();
      last unless defined $ext;
      push @slugs, $ext;
    }
    $rec->{slugs} = [@slugs];
  }
  return $stash;
}

get '/search' => sub {
  my $start = param('start') // 0;
  my $size  = param('size')  // 30;
  my $q     = param('q')     // '';
  template 'search', decorate( pager( search( $start, $size, $q ) ) );
};

true;
