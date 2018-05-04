package Lintilla::Role::ErrorLog;

use Moose::Role;

use Lintilla::ErrorLog;

=head1 NAME

Lintilla::Role::ErrorLog - ErrorLog mixin

=cut

has error_log => (
  is      => 'ro',
  isa     => 'Lintilla::ErrorLog',
  lazy    => 1,
  builder => '_b_errorlog',
  handles => [qw( fatal error warn note debug )]
);

sub _b_errorlog { Lintilla::ErrorLog->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
