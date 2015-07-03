package Lintilla::DB::Genome::Collection;

use Moose;

use DateTime;

=head1 NAME

Lintilla::DB::Genome::Where - Query labs potted collections

=cut

with 'Lintilla::Role::DB';
with 'Lintilla::Role::UUID';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Source';

sub list {
  my ($self, $collection, $order, $start, $size) = @_;
  return {};
}
