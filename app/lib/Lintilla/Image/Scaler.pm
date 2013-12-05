package Lintilla::Image::Scaler;

use Moose;
#use Dancer ':syntax';

use GD;
use LWP::UserAgent;
use List::Util qw( min max );
use Path::Class;

=head1 NAME

Lintilla::Image::Scaler - Scale / crop / pad an image

=cut

has ['in_file', 'in_url'] => ( is => 'ro' );
has out_file => ( is => 'ro' );
has spec => ( is => 'ro', isa => 'HashRef', required => 1 );

sub _fit {
  my $self = shift;
  my ( $iw, $ih, $mw, $mh ) = @_;
  my $sc = min( $mw / $iw, $mh / $ih );
  return ( int( $iw * $sc ), int( $ih * $sc ) );
}

sub _load_source {
  my $self = shift;
  if ( defined( my $in_file = $self->in_file ) ) {
    #    debug("loading $in_file");
    my $img = GD::Image->new("$in_file");
    defined $img or die "Can't load $in_file";
    return $img;
  }

  if ( defined( my $in_url = $self->in_url ) ) {
    #    debug("fetching $in_url");
    my $resp = LWP::UserAgent->new->get($in_url);
    die $resp->status_line if $resp->is_error;
    my $img = GD::Image->new( $resp->content );
    defined $img or die "Can't load $in_url";
    return $img;
  }

  die "No source provided (in_file or in_url)";
}

sub _save {
  my ( $self, $fn, $img, $quality ) = @_;
  $quality ||= 90;
  my $tmp = file("$fn.tmp");
  die "$tmp exists" if -e "$tmp";
  $tmp->parent->mkpath;
  my $of = $tmp->openw;
  $of->binmode;
  print $of $img->jpeg($quality);

  rename "$tmp", "$fn"
   or die "Can't link $tmp to $fn: $!\n";
}

sub fit {
  my ( $self, $iw, $ih ) = @_;
  my $spec = $self->spec;
  return $self->_fit( $iw, $ih, $spec->{width}, $spec->{height} )
   if $iw > $spec->{width} || $ih > $spec->{height};
  return ( $iw, $ih );
}

sub create {
  my $self     = shift;
  my $out_file = $self->out_file;
  my $img      = $self->_load_source;

  my ( $iw, $ih ) = $img->getBounds;
  my ( $ow, $oh ) = $self->fit( $iw, $ih );
  if ( $iw != $ow || $ih != $oh ) {
    my $thb = GD::Image->new( $ow, $oh, 1 );
    $thb->copyResampled( $img, 0, 0, 0, 0, $ow, $oh, $iw, $ih );
    $self->_save( $out_file, $thb );
  }
  else {
    $self->_save( $out_file, $img );
  }
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
