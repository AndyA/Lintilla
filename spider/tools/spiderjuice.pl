#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use DBI;
use Path::Class;
use URI;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'spider';
use constant DIR  => 'media';

{
  my $dbh = dbh();
  juice($dbh);
  $dbh->disconnect;
}

sub juice {
  my $dbh = shift;

  my $sth = $dbh->prepare( "SELECT url, url_hash FROM spider_page "
     . "WHERE mime LIKE 'audio/%' OR mime LIKE 'video/%'" );
  $sth->execute;
  while ( my $rec = $sth->fetchrow_hashref ) {
    my $url = URI->new( $rec->{url} );
    my $file = file DIR, split /\//, $url->path;
    next if -f $file;
    print "$url -> $file\n";
    {
      my @body
       = $dbh->selectrow_array(
        "SELECT body FROM spider_page WHERE url_hash=?",
        undef, $rec->{url_hash} );
      $file->parent->mkpath;
      {
        open my $fh, '>', $file;
        print $fh $body[0];
      }
    }
  }
}

sub dbh {
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', DB, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

