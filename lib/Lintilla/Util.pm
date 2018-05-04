package Lintilla::Util;

use strict;
use warnings;

use Time::HiRes qw( sleep time );

use base qw( Exporter );

our @EXPORT_OK = qw( wait_for_file tidy unique make_public );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Lintilla::Util - Utility stuff

=cut

sub wait_for_file {
  my ( $name, $timeout ) = @_;
  $name = "$name";    # stringify once
  return $name if -e $name;
  my $deadline = defined $timeout ? time + $timeout : undef;
  until ( defined $deadline && time >= $deadline ) {
    sleep 0.1;
    return $name if -e $name;
  }
  return;
}

sub tidy {
  my $s = shift;
  s/^\s+//, s/\s+$//, s/\s+/ /g for $s;
  return $s;
}

sub unique(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

sub make_public($);

sub make_public($) {
  my $in = shift;
  return $in unless ref $in;

  return [map { make_public($_) } @$in]
   if 'ARRAY' eq ref $in;

  die "Bad!" unless 'HASH' eq ref $in;

  my $out = {};
  while ( my ( $k, $v ) = each %$in ) {
    ( my $kk = $k ) =~ s/^_+//g;
    $out->{$kk} = make_public($v);
  }

  return $out;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
