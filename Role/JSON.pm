package Lintilla::Role::JSON;

use Moose::Role;

use Carp qw( confess );
use Encode qw( encode );
use JSON;

=head1 NAME

Lintilla::Role::JSON - JSON encode / decode

=cut

sub _json { JSON->new->utf8->allow_nonref->canonical }

sub _encode {
  my ( $self, $data ) = @_;
  return $self->_json->encode($data);
}

sub _decode {
  my ( $self, $data ) = @_;
  return undef unless $data;
  my $enc = eval { $self->_json->decode($data) };
  confess "$data caused $@" if $@;
  return $enc;
}

# Decode non-UTF8 data
sub _decode_wide {
  my ( $self, $data ) = @_;
  return undef unless $data;
  return $self->_json->decode( encode( 'UTF-8', $data ) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
