package Lintilla::Tools::Enqueue;

use Moose;

use HTML::Tiny;

=head1 NAME

Lintilla::Tools::Enqueue - Enqueue JS/CSs

=cut

has map => ( isa => 'HashRef', is => 'ro', required => 1 );

has _render => (
  traits  => ['Hash'],
  isa     => 'HashRef[CodeRef]',
  is      => 'ro',
  default => sub { {} },
  handles => { formatter => 'set' }
);

sub BUILD {
  my $self = shift;
  my $h    = HTML::Tiny->new;
  $self->formatter(
    css => sub {
      $h->link( { href => $_[0]{url}, rel => 'stylesheet' } );
    },
    js => sub {
      $h->script( { src => $_[0]{url}, type => 'text/javascript' } );
    }
  );
}

sub _resolve {
  my ( $self, $name ) = @_;
  my ( $type, $tag ) = split /\./, $name, 2;
  return ( $self->map->{$type}{$tag}, $type, $tag ) if wantarray;
  return $self->map->{$type}{$tag};
}

sub _expand {
  my ( $self, $seen, @obj ) = @_;
  my @list = ();
  for my $obj (@obj) {
    next if $seen->{$obj}++;
    my $rr = $self->_resolve($obj);
    push @list, $self->_expand( $seen, @{ $rr->{requires} // [] } ), $obj;
  }
  return @list;
}

sub expand {
  my $self = shift;
  return [$self->_expand( {}, @_ )];
}

sub render {
  my $self = shift;
  my $dep  = $self->expand(@_);
  my $rm   = $self->_render;
  my @out  = ();
  for my $obj (@$dep) {
    my ( $rr, $type, $tag ) = $self->_resolve($obj);
    my $rc = $rm->{$type} // die "No renderer for $type";
    push @out, $rc->($rr);
  }
  return join "\n", @out, '';
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
