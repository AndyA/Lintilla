package Lintilla::Image::PDFExtract;

use Moose;

=head1 NAME

Lintilla::Image::PDFExtract - Extract a page from a PDF

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

  ( my $out_tmp = $out_file ) =~ s/\.[^.]+$/-tmp/;

  # pdfimages -j -f 3 -l 3 pdf/1486tv.pdf ext/foo

  my @cmd = (
    'pdfimages',
    '-j',
    -f => $page,
    -l => $page,
    $in_tmp, $out_tmp
  );

  system @cmd;

  #  die "Result: $?" if $?;
  rename "${out_tmp}-000.jpg", $out_file or die $!;

  $in_tmp->parent->rmtree;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
