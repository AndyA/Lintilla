package Lintilla::Image::Scaler;

use Moose;
use Dancer ':syntax';

use Image::Size;
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

sub _find_source {
  my $self = shift;

  return ( file( $self->in_file ), sub { } ) if defined $self->in_file;

  my $in_url = $self->in_url;
  die "No source specified" unless defined $in_url;
  die "No extension" unless $in_url =~ m{\.([^/]+)$};
  my $ext = $1;

  my $tmp = file( Path::Class::tempdir, "tmp.$ext" );

  my $rs = LWP::UserAgent->new->get( $in_url, ':content_file' => "$tmp" );
  die $rs->status_line if $rs->is_error;

  return ( $tmp, sub { $tmp->parent->rmtree } );
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
  ( my $tmp_file = $out_file ) =~ s/\.([^.]+)$/.tmp.$1/;
  my ( $src, $cleanup ) = $self->_find_source;

  my ( $iw, $ih ) = imgsize("$src");
  my ( $ow, $oh ) = $self->fit( $iw, $ih );

  my @cmd = (
    'convert', $src, -strip => -resize => "${ow}x${oh}",
    -quality => $self->spec->{quality},
    $tmp_file
  );

  system @cmd; # and die "convert failed: $?";
  rename $tmp_file, $out_file or die $!;
  $cleanup->();
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
