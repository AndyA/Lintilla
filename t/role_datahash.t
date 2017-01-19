#!perl

use strict;
use warnings;

use lib qw( components/Fenchurch/lib );

use MooseX::Test::Role;
use Test::More;

use Lintilla::Role::DataHash;

my $cls = consuming_object('Lintilla::Role::DataHash');

my @test = (
  { in   => [],
    out  => '93601c505d2a5a4c84bbcd18b9def364',
    name => 'empty args'
  },
  { in   => [''],
    out  => '9985c123abc2d4300515c68d7664e918',
    name => 'scalar'
  },
  { in   => ['', ''],
    out  => 'c1526414fdf85ca239d27a17a4a9d4a4',
    name => 'multiple scalar'
  },
  { in   => [{}],
    out  => 'd34f2b4ded19764ac0d41921ab8bf334',
    name => 'empty hash'
  },
  { in   => [3.1415],
    out  => '94d36e3c5dc97eb2cb41005467f9f9e4',
    name => 'fp number'
  },
);

my %seen = ();
for my $tx (@test) {
  $seen{ $tx->{out} }++;
  is $cls->data_hash( @{ $tx->{in} } ), $tx->{out},
   "$tx->{name}: hash matches";
}

my @mult = grep { $seen{$_} > 1 } keys %seen;
ok !@mult, 'no hash dupes' or diag "Duplicated: ", join( ', ', @mult );

done_testing();

# vim:ts=2:sw=2:et:ft=perl

