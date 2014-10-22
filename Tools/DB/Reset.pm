package Lintilla::Tools::DB::Reset;

use Moose;

=head1 NAME

Lintilla::Tools::DB::Reset - Reset database 

=cut

with 'Lintilla::Tools::Role::EditDB';
with 'Lintilla::Tools::Role::ErrorLog';

sub load_changes {
  my ( $self, $uuid, $head ) = @_;

  my $changes = $self->group_by(
    $self->dbh->selectall_arrayref(
      'SELECT * FROM genome_changelog WHERE id <= ? AND uuid = ?',
      { Slice => {} },
      $head, $uuid
    ),
    'id'
  );

  unless ( keys %$changes ) {
    $self->error(
      ['changelog', $uuid],
      "Finding changes",
      "No changes found for $uuid below $head"
    );
    return;
  }

  # Build chronological list of changes
  my $next = $head;
  my @log  = ();
  while ( defined $next ) {
    my $rec = delete $changes->{$next};
    unless ( defined $rec ) {
      $self->error( ['changelog', $uuid],
        "Change $next", "Change $next is missing" );
      last;
    }
    my $ev = shift @$rec;
    if (@$rec) {
      $self->fatal( ['changelog', $uuid],
        "Change $next", "More than one change $next" );
      last;
    }
    if ( $ev->{uuid} ne $uuid ) {
      $self->error( ['changelog', $uuid],
        "Change $next",
        "Change $next has wrong UUID (program: $uuid, change: $ev->{uuid})" );
      last;
    }
    unshift @log, $ev;
    $next = $ev->{prev_id};
  }
  return $self->edit_db->decode_data( \@log );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
