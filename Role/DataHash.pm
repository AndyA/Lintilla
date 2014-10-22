package Lintilla::Role::DataHash;

use Moose::Role;

use Digest::MD5 qw( md5_hex );
use Storable qw( freeze );

=head1 NAME

Lintilla::Role::DataHash - Compute hash of data structure

=cut

#requires '_decode';

sub data_hash {
  my $self = shift;
  local $Storable::canonical = 1;
  return md5_hex( freeze [@_] );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
