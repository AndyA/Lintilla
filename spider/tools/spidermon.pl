#!/usr/bin/env perl

use v5.10;

use strict;
use warnings;

use DBI;
use JSON;
use Time::HiRes qw( sleep time );

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'spider';

my $quant = shift // 10;

{
  my $dbh = dbh(DB);

  my ( $prev, $prev_time );
  while () {
    my $info = get_progress($dbh);
    my $now  = time;
    my $data = $prev ? diff( $prev, $info, $now - $prev_time ) : $info;
    print scalar(localtime), "\n";
    print table( report($data) );
    print "\n";
    ( $prev, $prev_time ) = ( $info, $now );

    my $next = int( $now / $quant ) * $quant;
    $next += $quant if $next <= $now;
    sleep $next - $now;
  }

  $dbh->disconnect;
}

sub num_first {
  if ( $a =~ /^\d+$/ ) {
    return $a <=> $b if $b =~ /^\d+$/;
    return -1;
  }
  return 1 if $b =~ /^\d+$/;
  return $a cmp $b;
}

sub diff {
  my ( $a, $b, $dt ) = @_;
  my $m;
  overlay( \$m, $a, 0 );
  overlay( \$m, $b, 1 );
  return rdiff( $m, $dt );
}

sub rdiff {
  my ( $nd, $dt ) = @_;
  die unless ref $nd;
  return { map { $_ => rdiff( $nd->{$_}, $dt ) } keys %$nd }
   if 'HASH' eq ref $nd;
  die unless 'ARRAY' eq ref $nd;
  my $old = $nd->[0] // 0;
  my $new = $nd->[1] // 0;
  my $rate = ( $new - $old ) / $dt;
  return sprintf "%8d (%9.3f/s)", $new, $rate;
}

sub overlay {
  my ( $ov, $ha, $pos ) = @_;
  if ( ref $ha ) {
    if ( 'HASH' eq ref $ha ) {
      $$ov ||= {};
      for my $k ( keys %$ha ) {
        overlay( \( ($$ov)->{$k} ), $ha->{$k}, $pos );
      }
    }
    elsif ( 'ARRAY' eq ref $ha ) {
      $$ov ||= [];
      for my $k ( 0 .. $#$ha ) {
        overlay( \( ($$ov)->[$k] ), $ha->[$k], $pos );
      }
    }
    else { die }
    return;
  }
  ($$ov)->[$pos] = $ha;
}

sub table {
  my @tbl   = @{ shift() };
  my @width = ();
  for my $row (@tbl) {
    for my $cn ( 0 .. $#$row ) {
      my $len = length( $row->[$cn] // '' );
      $width[$cn] = $len unless defined $width[$cn] && $width[$cn] > $len;
    }
  }
  my $bar = '+' . join( '+', map { '-' x ( $_ + 2 ) } @width ) . '+';
  my $fmt = '|' . join( '|', map { " %-${_}s " } @width ) . '|';

  return join "\n", $bar, sprintf( $fmt, @{ shift @tbl } ), $bar, (
    map {
      sprintf( $fmt, map { defined $_ ? $_ : '' } @$_ )
    } @tbl
   ),
   $bar, '';
}

sub report {
  my $info = shift;
  my @rn   = sort num_first keys %$info;
  my %col  = ();
  $col{$_}++ for map { keys %$_ } values %$info;
  my @cn = sort keys %col;
  return [['rank', @cn], map { [$_, @{ $info->{$_} }{@cn}] } @rn];
}

sub get_progress {
  my $dbh  = shift;
  my $info = {};

  my @rep = @{
    $dbh->selectall_arrayref(
      "SELECT IF(last_visit=0,'pending','done') AS status, COUNT(*) AS freq, rank "
       . "FROM spider_page GROUP BY rank, status",
      { Slice => {} }
    ) };

  for my $itm (@rep) {
    $info->{ $itm->{rank} }{ $itm->{status} } = $itm->{freq};
    $info->{total}{ $itm->{status} } += $itm->{freq};
  }

  return $info;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
## Please see file perltidy.ERR
