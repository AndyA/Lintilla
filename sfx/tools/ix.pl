#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use URI;

use constant FEED => 'http://lintilla.fenkle/data/page/%d/%d';
use constant PAGE => 100;

my $ua = LWP::UserAgent->new;

my $pos = 0;
while () {
  my $url = sprintf FEED, PAGE, $pos;
  my $resp = $ua->get($url);
  die $resp->status_line unless $resp->is_success;
  my $page = JSON->new->decode( $resp->content );
  my $got  = @$page;
  for my $img (@$page) {
    for my $var ( values %{ $img->{var} } ) {
      my $iurl = URI->new_abs( $var->{url}, $url );
      print "$iurl\n";
    }
  }
  $pos += PAGE;
  last unless $got == PAGE;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

