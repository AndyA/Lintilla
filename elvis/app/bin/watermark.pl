#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use File::Find;
use GD;
use Getopt::Long;
use List::Util qw( min );
use Path::Class;

use constant USAGE => <<EOT;
Syntax: $0 [options] <dirs or images>...

Options:
    -w, --watermark <img> Watermark image
        --width i   <n>   Max watermark width as % of image
        --height    <n>   Max watermark height as % of image
    -x              <n>   Watermark X pos as a %
    -y              <n>   Watermark Y pos as a %
    -o, --output    <dir> Output dir
    -h, --help            See this message

Examples:

# Watermark in bottom right corner
$0 -w watermark.png --width 10 --height 10 -x 90 -y 90 myimages/

EOT

my %O = (
  watermark => undef,
  output    => "watermarked",
  width     => 100,
  height    => 100,
  x         => 10,
  y         => 10,
  help      => undef,
);

GetOptions(
  'w|watermark:s' => \$O{watermark},
  'o|output:s'    => \$O{output},
  'width:s'       => \$O{width},
  'height:s'      => \$O{height},
  'x:s'           => \$O{x},
  'y:s'           => \$O{y},
  'h|help'        => \$O{help},
) or die USAGE;
exit print USAGE if $O{help};

die "The --watermark option is required\n"
 unless defined $O{watermark};

my $wm = GD::Image->new( $O{watermark} );
die "Can't load $O{watermark}\n" unless $wm;

find_deep(
  sub {
    my ( $src, $rel ) = @_;
    my $dst = file $O{output}, $rel;
    return unless $dst->basename =~ /\.(?:jpe?g|png)$/i;
    say "Watermarking $src as $dst";
    $dst->parent->mkpath;
    watermark( $src, $dst, $wm, %O );
  },
  @ARGV
);

sub round($) { int $_[0] + 0.5 }

sub watermark {
  my ( $src, $dst, $wm, %opt ) = @_;

  my $img = GD::Image->new("$src");
  unless ($img) {
    warn "Can't load $src\n";
    return;
  }

  my ( $ww, $wh ) = $wm->getBounds;
  my ( $iw, $ih ) = $img->getBounds;

  my $maxw = $iw * $opt{width} / 100;
  my $maxh = $ih * $opt{height} / 100;

  my $scale = min( $maxw / $ww, $maxh / $wh );
  my $ow    = round( $ww * $scale );
  my $oh    = round( $wh * $scale );
  my $ox    = ( $iw - $ow ) * $opt{x} / 100;
  my $oy    = ( $ih - $oh ) * $opt{y} / 100;

  $img->copyResampled( $wm, $ox, $oy, 0, 0, $ow, $oh, $ww, $wh );
  save_image( $dst, $img );
}

sub save_image {
  my ( $file, $img ) = @_;
  my $fh = file($file)->openw;
  if ( $file =~ /\.jpe?g$/ ) {
    $fh->print( $img->jpeg );
  }
  elsif ( $file =~ /\.png$/ ) {
    $fh->print( $img->png );
  }
}

sub find_deep {
  my ( $cb, @root ) = @_;

  for my $obj (@root) {
    if ( -f $obj ) {
      my $ofile = file $obj;
      $cb->( $ofile, $ofile->basename );
    }
    else {
      find {
        no_chdir => 1,
        wanted   => sub {
          return unless -f;
          my $ofile = file $_;
          return if $ofile->basename =~ /^\./;
          $cb->( $ofile, $ofile->relative($obj) );
        }
      }, $obj;
    }
  }

}

# vim:ts=2:sw=2:sts=2:et:ft=perl

