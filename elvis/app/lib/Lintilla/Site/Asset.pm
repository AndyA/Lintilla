package Lintilla::Site::Asset;

use Dancer ':syntax';
use Lintilla::Filter qw( filter );
use Lintilla::Image::Scaler;
use Lintilla::Magic::Asset;
use Moose;
use Path::Class;

=head1 NAME

Lintilla::Site::Asset - Asset handling

=cut

# TODO move this into a config file.
my %RECIPE = (
  display => {
    width   => 1024,
    height  => 576,
    quality => 95,
    rotate  => 0,
  },
  display_high => {
    width   => 1280,
    height  => 720,
    quality => 95,
    rotate  => 0,
  },
  display_hd => {
    width   => 1920,
    height  => 1080,
    quality => 95,
    rotate  => 0,
  },
  info => {
    width   => 512,
    height  => 512,
    quality => 95,
    rotate  => 0,
  },
  thumb => {
    width   => 80,
    height  => 80,
    quality => 75,
    rotate  => 0,
    base    => 'display_high',
  },
  icon => {
    width   => 40,
    height  => 40,
    quality => 75,
    rotate  => 0,
    base    => 'display_high',
  },
  small => {
    width   => 200,
    height  => 200,
    quality => 75,
    rotate  => 0,
    base    => 'display_high',
  },
  slice => {
    width   => 800,
    height  => 150,
    quality => 85,
    rotate  => 0,
    base    => 'display_high',
  },
);

get '/data/recipe' => sub { \%RECIPE };

sub our_uri_for {
  my $uri = request->uri_for( join '/', '', @_ );
  $uri =~ s@/dispatch\.f?cgi/@/@;    # hack
  $uri =~ s/^https:/http:/;          # more hack
  return $uri;
}

sub url_for_asset {
  my ( $asset, $variant ) = @_;

  my @p = $asset->{hash} =~ /^(.{3})(.{3})(.+)$/;
  my $name = join( '/', @p ) . '.jpg';

  return "/asset/$name" unless defined $variant && $variant ne 'full';
  return "/asset/var/$variant/$name";
}

filter assets => sub {
  my $data = shift;
  for my $asset (@$data) {
    $asset->{var}{full} = {
      width  => $asset->{width} * 1,
      height => $asset->{height} * 1,
      url    => url_for_asset($asset),
    };
    for my $recipe ( keys %RECIPE ) {
      my $sc = Lintilla::Image::Scaler->new( spec => $RECIPE{$recipe} );
      my ( $vw, $vh, $rot )
       = $sc->fit( $asset->{width} * 1, $asset->{height} * 1 );
      $asset->{var}{$recipe} = {
        width    => $vw,
        height   => $vh,
        rotation => $rot,
        url      => url_for_asset( $asset, $recipe ),
      };
    }
  }
  return $data;
};

get '/asset/var/*/**.jpg' => sub {
  my ( $recipe, $id ) = splat;

  debug "recipe: $recipe, id: @$id";

  die "Bad recipe" unless $recipe =~ /^\w+$/;
  my $spec = $RECIPE{$recipe};
  die "Unknown recipe $recipe" unless defined $spec;

  my @name = @$id;
  $name[-1] .= '.jpg';

  my @p = ('asset');
  my @v = ( var => $recipe );

  my $in_url = our_uri_for( @p,
    ( defined $spec->{base} ? ( var => $spec->{base} ) : () ), @name );

  my $out_file = file setting('public'), @p, @v, @name;

  debug "in_url: $in_url";
  debug "out_file: $out_file";

  my $sc = Lintilla::Image::Scaler->new(
    in_url   => $in_url,
    out_file => $out_file,
    spec     => $spec
  );

  my $magic = Lintilla::Magic::Asset->new(
    filename => $out_file,
    timeout  => 20,
    provider => $sc
  );

  $magic->render or die "Can't render";

  my $self = our_uri_for( @p, @v, @name );

  return redirect $self, 307;
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
