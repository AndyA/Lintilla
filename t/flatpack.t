#!perl

use autodie;
use strict;
use warnings;

use lib qw( components/Fenchurch/lib );

use FindBin '$RealBin';
use JSON ();
use Lintilla::Util::Flatpack qw( flatpack unflatpack );
use Path::Class;
use Test::Differences;
use Test::More;

my $df = file $RealBin, 'data', 'flatpack.json';
my $tests = JSON->new->decode( scalar $df->slurp );

for my $tc (@$tests) {
  my $name      = $tc->{name};
  my $in        = $tc->{input};
  my $out       = $tc->{output};
  my $roundtrip = $tc->{roundtrip} // $tc->{input};

  my $got_out = flatpack($in);
  eq_or_diff $got_out, $out, "$name: flatpack";

  my $got_in = unflatpack($out);
  eq_or_diff $got_in, $roundtrip, "$name: unflatpack";
}

done_testing();

# vim:ts=2:sw=2:et:ft=perl

