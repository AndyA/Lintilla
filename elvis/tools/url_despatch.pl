#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Data::Dumper;
use HTML::LinkExtor;
use URI;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'elvis';

$| = 1;

{
  my $dbh = dbh(DB);

  my $sel
   = $dbh->prepare( 'SELECT acno, annotation '
     . 'FROM elvis_image '
     . 'WHERE annotation LIKE "%http://%"' );

  $sel->execute;
  while ( my $row = $sel->fetchrow_hashref ) {
    print $row->{acno}, "\n";
    my %upd = ();
    my @l   = flatten( get_links( $row->{annotation} ) );
    for my $url (@l) {
      if ( $url
        =~ m{\Qhttp://maps.google.com/maps?q=\E(-?\d+(?:\.\d+)),(-?\d+(?:\.\d+))}
       ) {
        @upd{ 'latitude', 'longitude' } = ( $1, $2 );
      }
    }
    if ( keys %upd ) {
      my @k = sort keys %upd;
      for my $k (@k) {
        printf "  %-10s = %s\n", $k, $upd{$k};
      }
      $dbh->do(
        join( ' ',
          "UPDATE elvis_image SET",
          join( ', ', map { "`$_`=?" } @k ),
          "WHERE acno=?" ),
        {},
        @upd{@k},
        $row->{acno}
      );
    }
  }

  $dbh->disconnect;
}

sub flatten {
  my @out;
  for my $ent (@_) {
    my ( undef, %h ) = @$ent;
    push @out, values %h;
  }
  return @out;
}

sub get_links {
  my ($doc) = @_;
  my $p = HTML::LinkExtor->new;
  $p->parse($doc);
  return $p->links;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
