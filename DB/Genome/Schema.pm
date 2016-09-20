package Lintilla::DB::Genome::Schema;

use v5.10;

use strict;
use warnings;

use Fenchurch::Adhocument::Schema;

=head1 NAME

Lintilla::DB::Genome::Schema - The Genome schema

=head2 << schema >>

Class method that returns a new Genome schema.

=cut

sub schema {
  my $class = shift;
  return Fenchurch::Adhocument::Schema->new(
    schema => {
      programme => {
        table  => 'genome_programmes_v2',
        pkey   => '_uuid',
        plural => 'programmes',
      },
      contributor => {
        table    => 'genome_contributors',
        child_of => { programme => '_parent' },
        order    => '+index',
        plural   => 'contributors',
      },
      related => {
        table    => 'genome_related_merged',
        pkey     => '_uuid',
        child_of => { programme => '_parent' },
      },
      edit => {
        table  => 'fenchurch_edit',
        pkey   => 'uuid',
        plural => 'edits',
        json   => ['old_data', 'new_data'],
      },
    }
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
