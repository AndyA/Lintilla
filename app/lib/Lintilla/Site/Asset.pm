package Lintilla::Site::Asset;

use Dancer ':syntax';
use Lintilla::Image::Scaler;
use Lintilla::Magic::Asset;
use Moose;
use Path::Class;

=head1 NAME

Lintilla::Site::Asset - Asset handling

=cut

use constant DOCROOT => '/opt/lintilla/app/public';    # FIXME

# TODO move this into a config file.
my %RECIPE = (
  display => {
    width  => 1024,
    height => 576,
  },
  thumb => {
    width  => 80,
    height => 80,
    base   => 'display',
  },
  small => {
    width  => 200,
    height => 200,
    base   => 'display',
  },
  slice => {
    width  => 800,
    height => 150,
    base   => 'display',
  },
);

get '/data/recipe' => sub { \%RECIPE };

sub our_uri_for {
  my $uri = request->uri_for( join '/', '', @_ );
  $uri =~ s@/dispatch\.f?cgi/@/@;    # hack
  return $uri;
}

get '/asset/**/var/*/*.jpg' => sub {
  my ( $path, $recipe, $id ) = splat;

  die "Bad recipe" unless $recipe =~ /^\w+$/;
  my $spec = $RECIPE{$recipe};
  die "Unknown recipe $recipe" unless defined $spec;

  my $name = "$id.jpg";

  my @p = ( asset => @$path );
  my @v = ( var   => $recipe );

  my $in_url = our_uri_for( @p,
    ( defined $spec->{base} ? ( var => $spec->{base} ) : () ), $name );

  my $out_file = file( DOCROOT, @p, @v, $name );

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

  my $self = our_uri_for( @p, @v, $name );

  return redirect $self, 307;
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
