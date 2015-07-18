package Lintilla::Util::Permute;

use Moose;

=head1 NAME

Lintilla::Util::Permute - Permute lists of words

=cut

has ['_prune', '_snip', '_stop'] => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0
);

sub prune { shift->_prune(1) }
sub snip  { shift->_snip(1) }
sub stop  { shift->_stop(1) }

sub _permute {
  my ( $self, $cb, $prefix, @tail ) = @_;
  my @head = ();
  while (@tail) {
    my $word = shift @tail;
    my @prefix = ( @$prefix, $word );

    $self->_prune(0);
    $self->_snip(0);

    $cb->( $self, @prefix );

    return if $self->_stop;
    my $snip = $self->_snip;

    $self->_permute( $cb, \@prefix, @head, @tail )
     unless $self->_prune;

    return if $self->_stop;

    push @head, $word
     unless $snip;
  }
}

sub permute {
  my ( $self, $cb, @words ) = @_;
  $self->_stop(0);
  return $self->_permute( $cb, [], @words );
}

1;
