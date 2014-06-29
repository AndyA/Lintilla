#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use DBI;
use Path::Class;
use URI::file;
use URI;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'spider';
use constant WORK => 'work';
use constant PAGE => 10_000;

if (1) {
  my $dbh = dbh();
  add_plain($dbh);
  $dbh->disconnect;
}
else {
  my $html = file('test.html')->slurp;
  print make_plain($html);
}

sub add_plain {
  my $dbh = shift;

  my $from = join ' ',
   'FROM spider_page pa ',
   'LEFT JOIN spider_plain pl ON pl.url_hash = pa.url_hash ',
   'WHERE pl.url_hash IS NULL AND pa.mime = "text/html" AND pa.code BETWEEN 200 AND 299';

  print "Counting eligible pages\n";
  my $count = ( $dbh->selectrow_array("SELECT COUNT(pa.url) $from") )[0];
  my $done  = 0;
  print "Processing $count pages\n";

  while () {
    my $rows
     = $dbh->selectall_arrayref(
      "SELECT pa.url, pa.url_hash, pa.body $from LIMIT " . PAGE,
      { Slice => {} } );
    last unless @$rows;
    for my $rec (@$rows) {
      my $plain = make_plain( $rec->{body} );
      $dbh->do( "INSERT INTO spider_plain (url_hash, plain) VALUES (?, ?)",
        {}, $rec->{url_hash}, $plain );
      $done++;
      printf "\r%10d/%10d (%6.2f)", $done, $count, $done * 100 / $count;
    }
  }

  print "\n";

}

sub make_plain {
  state $seq = 0;
  my $html = shift;
  my $tmp = file( WORK, sprintf "%s.%08d.html", $$, $seq++ );
  $tmp->parent->mkpath;
  print { $tmp->openw } $html;
  my $uri = URI::file->new($tmp);
  chomp( my $plain = `links -dump $uri` );
  $tmp->remove;
  return $plain;
}

sub safe {
  my $name = shift;
  $name =~ s/[\/\\:]/_/g;
}

sub hash2path {
  my $hash = shift;
  die unless $hash =~ /^(..)(..)(.+)$/;
  return ( $1, $2, $3 );
}

sub dbh {
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', DB, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

## Please see file perltidy.ERR
