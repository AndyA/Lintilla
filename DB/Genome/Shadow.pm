package Lintilla::DB::Genome::Shadow;

use Moose;

=head1 NAME

Lintilla::DB::Genome::Shadow - Work with shadow_* tables

=cut

with 'Lintilla::Role::DB';

sub _load_changes {
  my ( $self, $from, $to ) = @_;

  my $index = $self->dbh->selectall_arrayref(
    join( " ",
      "SELECT *",
      "FROM `shadow_x_log`",
      "WHERE `id` BETWEEN ? AND ?",
      "ORDER BY `id`" ),
    { Slice => {} },
    $from, $to
  );

  return [] unless @$index;    # Empty?

  # Group by table name
  my $plan = $self->stash_by( $index, "table" );
  my $stash = {};

  # Load from the individual tables
  while ( my ( $table, $info ) = each %$plan ) {
    my @ids = map { $_->{sequence} } @$info;
    $stash->{$table} = $self->dbh->selectall_arrayref(
      join( " ",
        "SELECT *" . "FROM `$table`",
        "WHERE `sequence` IN(",
        join( ", ", map "?", @ids ),
        ") ORDER BY `sequence`" ),
      { Slice => {} },
      @ids
    );
  }

  my @changes = ();
  for my $row (@$index) {
    my $table    = $row->{table};
    my $sequence = $row->{sequence};
    my $event    = shift @{ $stash->{$table} // [] };
    die unless defined $event && $event->{sequence} == $sequence;
    $event->{table} = $table;
    $event->{id}    = $row->{id};
    # Put NEW_*, OLD_* fields in 'new', 'old' hashes.
    for my $key ( keys %$event ) {
      $event->{old}{$1} = delete $event->{$key} if $key =~ /^OLD_(.+)$/;
      $event->{new}{$1} = delete $event->{$key} if $key =~ /^NEW_(.+)$/;
    }
    push @changes, $event;
  }

  return \@changes;
}

1;
