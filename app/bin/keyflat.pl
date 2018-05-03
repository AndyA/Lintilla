#!/usr/bin/env perl

use strict;
use warnings;

my %by_key   = ();
my %key_name = ();
while (<>) {
  chomp;
  my ( $key, $ids ) = split /\t/;
  $key =~ s/^\s+//;
  $key =~ s/\s+$//;
  $key =~ s/\s+/ /g;
  my $name = lc $key;
  $key_name{$name} = $key;
  push @{ $by_key{$name} }, split /\s*,\s*/, $ids;
}
for my $key ( sort { lc($a) cmp lc($b) } keys %by_key ) {
  printf "%s\t%s\n", $key_name{$key}, join ', ',
   sort { $a <=> $b } uniq( @{ $by_key{$key} } );
}

sub uniq {
  my %seen;
  grep { !$seen{$_} } @_;
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

