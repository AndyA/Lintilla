package Lintilla::DB::Genome::Edit;

#use Dancer ':syntax';
use JSON;
use Moose;

=head1 NAME

Lintilla::DB::Genome::Edit - Editing support

=cut

our $VERSION = '0.1';

with 'Lintilla::Role::DB';

sub audit {
  my $self = shift;
  my ( $edit_id, $who, $old_state, $new_state ) = @_;
  $self->dbh->do(
    join( ' ',
      'INSERT INTO genome_editlog',
      '  (`edit_id`, `who`, `old_state`, `new_state`, `when`)',
      '  VALUES (?, ?, ?, ?, NOW())' ),
    {},
    $edit_id, $who,
    $old_state,
    $new_state
  );
}

sub submit {
  my $self = shift;
  my ( $uuid, $kind, $who, $data ) = @_;
  my $dbh = $self->dbh;
  $self->transaction(
    sub {
      $dbh->do(
        'INSERT INTO genome_edit (`uuid`, `kind`, `data`) VALUES (?, ?, ?)',
        {}, $uuid, $kind, JSON->new->utf8->allow_nonref->encode($data) );
      my $edit_id = $dbh->last_insert_id( undef, undef, undef, undef );
      $self->audit( $edit_id, $who, undef, 'pending' );
    }
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
