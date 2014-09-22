package Lintilla::DB::Genome::Pages;

use Moose;

=head1 NAME

Lintilla::DB::Genome::Pages - Access page layout (coordinates)

=cut

with 'Lintilla::Role::JSON';
with 'Lintilla::Role::DB';

sub _numify {
  my ( $self, $hash, @key ) = @_;
  return [map { $self->_numify( $_, @key ) } @$hash]
   if 'ARRAY' eq ref $hash;
  for my $k (@key) {
    $hash->{$k} = 1 * $hash->{$k} if exists $hash->{$k};
  }
  return $hash;
}

sub pages {
  my ( $self, $issue ) = @_;
  my $pgs = $self->dbh->selectcol_arrayref(
    join( ' ',
      'SELECT `page`',
      'FROM genome_coordinates',
      'WHERE `issue`=?',
      'GROUP BY `page`',
      'ORDER BY `page`' ),
    {},
    $self->format_uuid($issue)
  );
  return $pgs;
}

sub page {
  my ( $self, $issue, $page ) = @_;
  my $coord = $self->group_by(
    $self->_numify(
      $self->dbh->selectall_arrayref(
        join( ' ',
          'SELECT *',
          'FROM genome_coordinates',
          'WHERE `issue`=?',
          'AND `page`=?',
          'ORDER BY `index`' ),
        { Slice => {} },
        $self->format_uuid($issue),
        $page
      ),
      qw( x y w h index )
    ),
    '_parent'
  );

  my @id = keys %$coord;
  return [] unless @id;

  my $prog = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_programmes_v2',
      'WHERE _uuid IN (',
      join( ', ', map { "?" } @id ),
      ')' ),
    { Slice => {} },
    @id
  );

  for my $p (@$prog) {
    $p->{coordinates} = $coord->{ $p->{_uuid} };
  }

  return $prog;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
