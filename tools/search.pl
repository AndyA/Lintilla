#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Sphinx::Search;

my $sph = Sphinx::Search->new();

my $results
 = $sph->SetMatchMode(SPH_MATCH_ALL)->SetSortMode(SPH_SORT_RELEVANCE)
 ->Query( "Andrew Marr", 'elvis_idx' );

print Dumper($results);

# vim:ts=2:sw=2:sts=2:et:ft=perl

