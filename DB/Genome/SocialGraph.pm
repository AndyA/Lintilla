package Lintilla::DB::Genome::SocialGraph;

use v5.10;

use Moose;

=head1 NAME

Lintilla::DB::Genome::SocialGraph - Labs social graph

=cut

with 'Lintilla::Role::DB';

use constant LIMIT => 100;

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
  my ( $self, $name, @extra ) = @_;
  my $id = $self->_contributor_by_name($name);
  return { status => 'NOTFOUND' } unless defined $id;
  return $self->graph( $id, @extra );
}

sub _cook_graph {
  my ( $self, $graph ) = @_;
  return $graph;
}

sub _links_between {
  my ( $self, $limit, @ids ) = @_;
  my $in = join ', ', map "?", @ids;
  my $links = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM labs_social_graph',
      "WHERE id_a IN ($in)",
      "AND id_b IN ($in)",
      'LIMIT ?' ),
    { Slice => {} },
    @ids, @ids, $limit
  );
  my $out  = [];
  my %seen = ();
  for my $link (@$links) {
    my @keys = sort { $a <=> $b } @{$link}{ 'id_a', 'id_b' };
    my $kk = join '-', @keys;
    next if $seen{$kk}++;
    push @$out,
     {from  => $keys[0],
      to    => $keys[1],
      count => $link->{count},
     };
  }
  return $out;
}

sub _graph {
  my ( $self, $id, $limit ) = @_;
  return $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT c.name, c.id, g.count',
      'FROM labs_social_graph AS g',
      'LEFT JOIN labs_contributors AS c ON c.id=g.id_b',
      'WHERE g.id_a=?',
      'ORDER BY `count` DESC',
      'LIMIT ?' ),
    { Slice => {} },
    $id, $limit
  );
}

sub random {
  my ( $self, $limit ) = @_;
}

sub graph {
  my ( $self, $id, $limit ) = @_;
  $limit //= LIMIT;

  my $graph = $self->_graph( $id, $limit );

  return { status => 'NOTFOUND' } unless @$graph;

  my @ids = map { $_->{id} } @$graph;

  return {
    status => 'OK',
    id     => $id,
    name   => $self->_contributor_by_id($id),
    graph  => $self->_cook_graph($graph),
    #    links  => $self->_links_between( $limit * $limit, @ids ),
  };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
