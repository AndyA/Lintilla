#!perl

use strict;
use warnings;

use Data::Dumper;
use Test::More;

use Lintilla::DB::Spider;
{
  my $db = Lintilla::DB::Spider->new;
  ok $db, 'created';
}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

