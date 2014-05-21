package Lintilla::DB::Builder;

use Moose;

=head1 NAME

Lintilla::DB::Builder - Build queries

=cut

has database => ( is => 'ro', isa => 'String', required => 1 );

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
