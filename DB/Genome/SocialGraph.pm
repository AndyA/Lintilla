package Lintilla::DB::Genome::SocialGraph;

use v5.10;

use Moose;

=head1 NAME

Lintilla::DB::Genome::SocialGraph - Labs social graph

=cut

with 'Lintilla::Role::DB';

sub _canonicalise_name {
  my ( $self, $name ) = @_;
  $name =~ s/[^\s\w]+//g;
  $name =~ s/^\s*//;
  $name =~ s/\s*$//;
  $name =~ s/\s+/ /g;
  return lc $name;
}

sub _contributor_by_id {
  my ( $self, $id ) = @_;
  my ($name)
   = $self->dbh->selectrow_array(
    'SELECT `name` FROM labs_contributors WHERE `id`=?',
    {}, $id );
  return $name;
}

sub _contributor_by_name {
  my ( $self, $name ) = @_;
  my ($id)
   = $self->dbh->selectrow_array(
    'SELECT `id` FROM labs_contributors WHERE `name`=?',
    {}, $self->_canonicalise_name($name) );
  return $id;
}

sub search {
  my ( $self, $name ) = @_;
  my $id = $self->_contributor_by_name($name);
  return { status => 'NOTFOUND' } unless defined $id;
  return $self->graph($id);
}

sub _cook_graph {
  my ( $self, $graph ) = @_;
  return $graph;
}

sub graph {
  my ( $self, $id ) = @_;
  my $graph = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT c.name, c.id, g.count',
      'FROM labs_social_graph AS g',
      'LEFT JOIN labs_contributors AS c ON c.id=g.id_b',
      'WHERE g.id_a=?',
      'ORDER BY `count` DESC' ),
    { Slice => {} },
    $id
  );

  return { status => 'NOTFOUND' } unless @$graph;

  return {
    status => 'OK',
    id     => $id,
    name   => $self->_contributor_by_id($id),
    graph  => $self->_cook_graph($graph),
  };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
