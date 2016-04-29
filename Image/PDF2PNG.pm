package Lintilla::Image::PDF2PNG;

use Moose;

=head1 NAME

Lintilla::Image::PDF2PNG - Extract a page from a PDF

=cut

use LWP::UserAgent;
use Path::Class;

has in_url   => ( is => 'ro' );
has out_file => ( is => 'ro' );
has page     => ( is => 'ro' );

sub create {
  my $self = shift;

  my $in_url   = $self->in_url;
  my $out_file = $self->out_file;
  my $page     = $self->page;

  my $in_tmp = file( Path::Class::tempdir, "tmp.pdf" );

  my $rs
   = LWP::UserAgent->new->get( $in_url, ':content_file' => "$in_tmp" );
  die $rs->status_line if $rs->is_error;

  ( my $out_tmp = $out_file ) =~ s/\.([^.]+)$/.tmp.$1/;

  my @cmd = (
    'convert', '-verbose',
    -density => 300,
    $in_tmp . "[$page]", $out_tmp
  );

  @cmd = join( ' ', @cmd, '>', '/tmp/convert.log', '2>&1' );
  system @cmd;
  rename $out_tmp, $out_file or die $!;

  $in_tmp->parent->rmtree;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
