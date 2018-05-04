#!/usr/bin/perl -w

use strict;

use Test::More;
use Test::Differences;

use Lintilla::Util::Permute;

{
  my $perm = Lintilla::Util::Permute->new;

  eq_or_diff gather( $perm, "permute", "Foo" ), [["Foo"]], "permute one";
  eq_or_diff gather( $perm, "permute", "Foo", "Bar" ),
   [["Foo"], ["Foo", "Bar"], ["Bar"], ["Bar", "Foo"]],
   "permute two";

}

done_testing;

sub gather {
  my ( $obj, $method, @args ) = @_;
  my @got = ();
  $obj->$method(
    sub {
      my ( undef, @words ) = @_;
      push @got, \@words;
    },
    @args
  );
  return \@got;
}
