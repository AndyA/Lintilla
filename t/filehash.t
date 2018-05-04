#!perl

use strict;
use warnings;
use Test::More;

use Lintilla::FileHash;

use Digest::MD5;
use Path::Class;

{
  my $fh = Lintilla::FileHash->new;

  my %test = map { $_ => get_hash($_) } $0;
  while ( my ( $obj, $hash ) = each %test ) {
    my $fhf = $fh->for($obj);
    my $got = $fhf->hash;
    is $got, $hash, "$obj: hash is $hash";
    my $short = $fhf->short_hash;
    is $short, substr( $hash, 0, 8 ), "$obj: short hash is $short";
  }

}

done_testing;

sub get_hash {
  my $file = file( $_[0] );
  my $ctx  = Digest::MD5->new;
  $ctx->addfile( $file->openr );
  return $ctx->hexdigest;
}

# vim:ts=2:sw=2:et:ft=perl

