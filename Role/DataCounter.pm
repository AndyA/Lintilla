package Lintilla::Role::DataCounter;

use Moose::Role;

=head1 NAME

Lintilla::Role::DataCounter - do something

=cut

requires 'dbh';
requires 'transaction';

has on_bump => ( is => 'rw', isa => 'Maybe[CodeRef]' );

sub _expand_paths {
  my ( $self, $mode, $pfx, $this, @path ) = @_;
  my @out = ();
  unless ( ref $this ) {
    ( $this, @path ) = ( split( /\./, $this ), @path );
    $this = [$this];
  }
  return ( join '.', @$pfx, '*' ) if $mode eq 'common' && @$this > 1;
  for my $elt (@$this) {
    push @out, join( '.', @$pfx, $elt ) unless @path && $mode eq 'leaf';
    push @out, $self->_expand_paths( $mode, [@$pfx, $elt], @path ) if @path;
  }
  return @out;
}

sub _notify_bump {
  my ( $self, @path ) = @_;
  if ( my $ob = $self->on_bump ) {
    my @cp = $self->_expand_paths( 'common', [], @path );
    $ob->( $cp[-1] );
  }
}

sub bump {
  my ( $self, @path ) = @_;
  my @pp = ( 'ROOT', $self->_expand_paths( 'all', [], @path ) );
  $self->transaction(
    sub {
      $self->dbh->do(
        join( ' ',
          'INSERT INTO genome_data_counter ( `path`, `count` )',
          'VALUES',
          join( ', ', map { "( ?, 1 )" } @pp ),
          'ON DUPLICATE KEY UPDATE `count`=`count`+1' ),
        {},
        @pp
      );
    }
  );
  $self->_notify_bump(@path);
}

sub get_data_counts {
  my ( $self, @path ) = @_;

  my $oper = '=';
  my $query = join '.', map {
    $_ eq '*'
     ? do { $oper = 'LIKE'; '%' }
     : $_
  } split /\./, join '.', @path ? @path : ('*');

  my @bind = ( $query eq '%' ? () : ($query) );
  my $sql = join( ' ',
    'SELECT * FROM genome_data_counter',
    ( $query eq '%' ? () : ( 'WHERE `path`', $oper, '?' ) ) );

  my $counts = $self->dbh->selectall_hashref( $sql, 'path', {}, @bind );
  $_ = $_->{count} for values %$counts;
  return $counts;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
