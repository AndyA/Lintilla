package Lintilla::FileHash::File;

our $VERSION = "0.01";

use v5.10;

use Moose;

use Digest::MD5;
use Path::Class;
use Time::HiRes qw( time );

=head1 NAME

Lintilla::FileHash::File - Calculate MD5 for (volatile) file

=cut

has object => (
  isa      => 'Path::Class::File',
  is       => 'ro',
  required => 1,
);

has check_every => (
  isa      => 'Num',
  is       => 'ro',
  required => 1,
);

has short_hash_len => (
  isa      => 'Num',
  is       => 'ro',
  required => 1,
);

has _last_checked => (
  isa => 'Maybe[Num]',
  is  => 'rw',
);

has _last_mtime => (
  isa => 'Maybe[Num]',
  is  => 'rw',
);

has _last_sum => (
  isa => 'Maybe[Str]',
  is  => 'rw',
);

sub _md5 {
  my $self = shift;
  my $ctx  = Digest::MD5->new;
  $ctx->addfile( $self->object->openr );
  return $ctx->hexdigest;
}

sub hash {
  my $self = shift;

  my $last_checked = $self->_last_checked;
  my $last_sum     = $self->_last_sum;
  my $now          = time;

  return $last_sum
   if defined $last_checked
   && $last_checked + $self->check_every < $now;

  # Need to check file
  my $last_mtime = $self->_last_mtime;
  my $obj        = $self->object;
  my $mtime      = $obj->stat->mtime;

  # Modified?
  if ( defined $last_mtime && $mtime == $last_mtime ) {
    $self->_last_checked($now);
    return $last_sum;
  }

  my $sum = $self->_md5;

  # If the file changed go round again
  return $self->hash
   unless $mtime == $obj->stat->mtime;

  $self->_last_checked($now);
  $self->_last_mtime($mtime);
  $self->_last_sum($sum);

  return $sum;
}

sub short_hash {
  my $self = shift;
  substr $self->hash, 0, $self->short_hash_len;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# vim:ts=2:sw=2:sts=2:et:ft=perl
