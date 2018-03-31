package Lintilla::FileHash;

our $VERSION = "0.01";

use v5.10;

use Moose;

use Path::Class;

use Lintilla::FileHash::File;

=head1 NAME

Lintilla::FileHash - md5 hashes for files

=cut

has check_every => (
  isa      => 'Num',
  is       => 'ro',
  required => 1,
  default  => 10,
);

has short_hash_len => (
  isa      => 'Num',
  is       => 'ro',
  required => 1,
  default  => 8,
);

has _cache => (
  isa      => 'HashRef',
  is       => 'ro',
  required => 1,
  default  => sub { {} },
);

sub for {
  my ( $self, $file ) = @_;

  my $obj = file($file)->absolute;

  return $self->_cache->{"$obj"} //= Lintilla::FileHash::File->new(
    object         => $obj,
    check_every    => $self->check_every,
    short_hash_len => $self->short_hash_len,
  );
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
