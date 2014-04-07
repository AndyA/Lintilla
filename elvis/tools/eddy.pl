#!/usr/bin/env perl

# Generate a manifest file like this:
#
#   find elvis -type f -print0 | xargs -0 sha1sum | sort > elvis.manifest
#
# and then
#
#   perl tools/eddy.pl < elvis.manifest

use strict;
use warnings;

use Data::Dumper;

my %by        = ();
my %report    = ();
my $show_load = mk_whizzer();
while (<>) {
  chomp;
  my %rec = ();
  @rec{ 'hash', 'file' } = split /\s+/, $_, 2;
  $show_load->("$rec{hash} $rec{file}");
  next unless $rec{file} =~ m{^(.+?)/(\d+)\.(jpg|xml)$};
  @rec{ 'path', 'acno', 'ext' } = ( $1, $2, $3 );
  poke( $by{hash} ||= {}, \%rec, 'hash' );
  poke( $by{acno} ||= {}, \%rec, 'acno', 'ext', 'hash' );
  poke( $by{path} ||= {}, \%rec, 'path', 'acno', 'ext', 'hash' );
}

print "\n";

check_acno( $report{acno} ||= {}, $by{acno} );
check_by_path( $report{path} ||= {}, $by{path} );

print "\n";

show_hist( $report{acno} );
show_by_path( $report{path} );

sub show_by_path {
  my $report = shift;
  for my $path ( sort keys %$report ) {
    print "$path:\n";
    show_hist( $report->{$path} );
  }
}

sub show_hist {
  my $hist = shift;
  for my $key ( sort { $hist->{$b} <=> $hist->{$a} } keys %$hist ) {
    printf "%12d %s\n", $hist->{$key}, $key;
  }
  print "\n";
}

sub check_by_path {
  my ( $report, $by_path ) = @_;
  for my $path ( sort keys %$by_path ) {
    check_acno( $report{path}{$path} ||= {}, $by_path->{$path} );
  }
}

sub check_acno {
  my ( $report, $by_acno ) = @_;
  my $wh = mk_whizzer();
  for my $acno ( sort { $a <=> $b } keys %$by_acno ) {
    $wh->( sprintf "%12d", $acno );
    my %got = ( jpg => 0, xml => 0 );
    while ( my ( $k, $v ) = each %{ $by_acno->{$acno} } ) {
      $got{$k} += keys %$v;
    }
    my $key = flatten( \%got );
    $report->{$key}++;
  }
  print "\n";
}

sub flatten {
  my $hash = shift;
  join ', ', map { "$_: $hash->{$_}" } sort keys %$hash;
}

sub poke {
  my ( $stash, $rec, $key, @tail ) = @_;

  if (@tail) {
    poke( $stash->{ $rec->{$key} } ||= {}, $rec, @tail );
    return;
  }

  push @{ $stash->{ $rec->{$key} } ||= [] }, $rec;
}

sub mk_whizzer {
  my $width = 0;
  return sub {
    my $msg = ( split /\n/, join '', @_ )[-1];
    my $nw  = length $msg;
    my $pad = $nw < $width ? ( ' ' x ( $width - $nw ) ) : '';
    print "\r$msg$pad";
    $width = $nw;
  };
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

