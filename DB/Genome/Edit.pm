package Lintilla::DB::Genome::Edit;

#use Dancer ':syntax';
use JSON;
use Moose;

=head1 NAME

Lintilla::DB::Genome::Edit - Editing support

=cut

our $VERSION = '0.1';

has dbh => ( is => 'ro', isa => 'DBI::db' );

sub submit {
  my $self = shift;
  my ( $uuid, $kind, $who, $data ) = @_;
  $self->dbh->do(
    'INSERT INTO genome_edit (`uuid`, `kind`, `who`, `created`, `data`) VALUES (?, ?, ?, NOW(), ?)',
    {}, $uuid, $kind, $who, JSON->new->utf8->allow_nonref->encode($data)
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
