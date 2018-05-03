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

  $dbh->do('TRUNCATE elvis_location');

  my $sel
   = $dbh->prepare( 'SELECT acno, annotation '
     . 'FROM elvis_image '
     . 'WHERE annotation LIKE "%http://%" '
     . 'ORDER BY acno' );
  $sel->execute;
  while ( my $row = $sel->fetchrow_hashref ) {
    print $row->{acno}, "\n";
    my %upd = ();
    my @l   = flatten( get_links( $row->{annotation} ) );
    for my $url (@l) {
      if ( $url
        =~ m{\Qhttp://maps.google.com/maps?q=\E(-?\d+(?:\.\d+)),(-?\d+(?:\.\d+))}
       ) {
        my ( $lat, $lon ) = ( $1, $2 );
        print "  latitude: $lat, longitude: $lon\n";
        eval {
          $dbh->do(
            'INSERT INTO elvis_location (acno, latitude, longitude) VALUES (?, ?, ?)',
            {}, $row->{acno}, $lat, $lon
          );
        };
        print "*** $@\n" if $@;
      }
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
