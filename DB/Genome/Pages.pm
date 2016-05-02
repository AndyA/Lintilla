package Lintilla::DB::Genome::Pages;

use Moose;

=head1 NAME

Lintilla::DB::Genome::Pages - Access page layout (coordinates)

=cut

with 'Lintilla::Role::JSON';
with 'Lintilla::Role::DB';
with 'Lintilla::Role::UUID';
with 'Lintilla::Role::Genome';

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

sub _issue_key {
  my ( $self, $issue ) = @_;
  return $issue->{default_child_key}
   if defined $issue->{default_child_key};
  return $issue->{_key};
}

sub _issue_page_path {
  my ( $self, $issue ) = @_;
  my $key = $self->_issue_key($issue);
  return join '/', '', 'page', 'asset', $issue->{decade}, $issue->{year},
   $key, $key, '%d.png';
}

sub _load_issue {
  my ( $self, $uuid ) = @_;

  my $issue = $self->dbh->selectall_arrayref(
    'SELECT * FROM genome_issues WHERE _uuid = ?',
    { Slice => {} },
    $self->format_uuid($uuid)
  );

  for my $iss (@$issue) {
    $iss->{page_image} = $self->_issue_page_path($iss);
  }

  return $self->_numify( $issue->[0],
    qw( day decade issue month pagecount volume year ) );
}

sub _load_programme {
  my ( $self, $uuid ) = @_;

  my $prog = $self->dbh->selectall_arrayref(
    'SELECT * FROM genome_programmes_v2 WHERE _uuid = ?',
    { Slice => {} },
    $self->format_uuid($uuid)
  )->[0];

  return unless defined $prog;

  $prog->{coordinates} = $self->_numify(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_coordinates WHERE _parent = ?',
        'ORDER BY `page`, `index`' ),
      { Slice => {} },
      $self->format_uuid($uuid)
    ),
    qw( x y w h page index )
  );

  return $prog;
}

sub pages_for_thing {
  my ( $self, $uuid ) = @_;
  my $kind = $self->lookup_kind($uuid);
  die "Can't find $uuid" unless defined $kind;

  if ( $kind eq 'programme' ) {
    my $prog = $self->_load_programme($uuid);
    die "Can't find programme $uuid" unless defined $prog;
    my $issue = $self->_load_issue( $prog->{issue} );
    die "Can't find issue for $uuid" unless defined $issue;
    my $page = $prog->{coordinates}[0]{page} // 1;

    return {
      issue     => $issue,
      programme => $prog,
      image     => sprintf( $issue->{page_image}, $page ),
      page      => $page,
    };
  }
  elsif ( $kind eq 'issue' ) {
    my $issue = $self->_load_issue($uuid);
    die "Can't find issue $uuid" unless defined $issue;

    return {
      issue => $issue,
      image => sprintf( $issue->{page_image}, 1 ),
      page  => 1,
    };
  }
  else {
    die "Can't handle a $kind";
  }

}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
