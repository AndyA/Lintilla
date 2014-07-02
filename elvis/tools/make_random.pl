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

  my $count
   = ( $dbh->selectrow_array('SELECT COUNT(acno) FROM elvis_image') )[0];

  my $shape = describe_table( $dbh, 'elvis_random' );
  my @fields = grep { /^r\d+$/ } map { $_->{Field} } @$shape;
  my $range = int( $count**( 1 / scalar @fields ) + 1 );

  $dbh->do('TRUNCATE elvis_random');
  $dbh->do('INSERT INTO elvis_random (acno) SELECT acno FROM elvis_image');

  my $rand = "FLOOR(RAND() * $range)";
  my $sql = join ' ', 'UPDATE elvis_random SET',
   join( ', ', map { "$_ = $rand" } @fields );

  $dbh->do($sql);

  $dbh->disconnect;
}

sub describe_table {
  my ( $dbh, $tbl ) = @_;
  return $dbh->selectall_arrayref( "DESCRIBE `$tbl`", { Slice => {} } );
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

