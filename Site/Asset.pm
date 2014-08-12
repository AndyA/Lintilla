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
  cover_lg => {
    width   => 320,
    height  => 425,
    quality => 90,
  },
  cover_sm => {
    width   => 128,
    height  => 170,
    quality => 90,
    base    => 'cover_lg',
  },
);

get '/data/recipe' => sub { \%RECIPE };

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub url_for_asset {
  my ( $name, $variant ) = @_;

  return "/asset/$name" unless defined $variant && $variant ne 'full';
  return "/asset/var/$variant/$name";
}

filter issues => sub {
  my $data = shift;
  for my $issue (@$data) {
    $issue->{var}{full} = { url => url_for_asset( $issue->{path} ), };
    for my $recipe ( keys %RECIPE ) {
      $issue->{var}{$recipe}
       = { url => url_for_asset( $issue->{path}, $recipe ), };
    }
  }
  return $data;
};

get '/asset/var/*/**' => sub {
  my ( $recipe, $id ) = splat;

  debug "recipe: $recipe, id: @$id";

  die "Bad recipe" unless $recipe =~ /^\w+$/;
  my $spec = $RECIPE{$recipe};
  die "Unknown recipe $recipe" unless defined $spec;

  my @name = @$id;
  #  $name[-1] .= '.jpg';

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
