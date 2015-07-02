package Lintilla::DB::Genome::Where;

use Moose;

use DateTime;

=head1 NAME

Lintilla::DB::Genome::Where - A bunch of potted queries

=cut

with 'Lintilla::Role::DB';
with 'Lintilla::Role::UUID';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Source';

# Potted queries

my @QUERIES = (
  {
    name => "Programmes with related text",
    query => "";
  }

);
