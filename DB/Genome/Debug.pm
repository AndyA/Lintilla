package Lintilla::DB::Genome::Debug;

use v5.10;

use Dancer ':syntax';
use Moose;
use Encode qw( encode decode );

with 'Lintilla::Role::JSON';
with 'Lintilla::Role::DB';

=head1 NAME

Lintilla::DB::Genome::Debug - Debug access to DB

=cut

sub debug_stash {
  shift->dbh->selectall_arrayref( 'SELECT * FROM genome_debug',
    { Slice => {} } );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
