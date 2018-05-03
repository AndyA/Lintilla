#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Data::Dumper;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'elvis';

$| = 1;

{
  my $dbh = dbh(DB);

  while (<>) {
    chomp;
    my ( $key, $ids ) = split /\t/;
    my ( $first, @other ) = split /\s*,\s*/, $ids;

    printf "%s\t%s\n", $key, join ', ', $first, @other;

    $dbh->do( 'UPDATE elvis_keyword SET name=? WHERE id=?',
      {}, $key, $first );
    if (@other) {
      $dbh->do(
        join( '',
          'UPDATE elvis_image_keyword SET id=? WHERE id IN (',
          join( ', ', map { '?' } @other ), ')' ),
        {},
        $first, @other
      );
      $dbh->do(
        join( '',
          'DELETE FROM elvis_image_keyword WHERE id IN (',
          join( ', ', map { '?' } @other ),
          ')' ),
        {},
        @other
      );
    }
  }

  $dbh->do(
    join '',
    'DELETE elvis_keyword ',
    'FROM elvis_keyword ',
    'LEFT JOIN elvis_image_keyword ON elvis_image_keyword.id=elvis_keyword.id ',
    'WHERE elvis_image_keyword.acno IS NULL'
  );

  $dbh->disconnect;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

