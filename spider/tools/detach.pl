#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use DBI;
use Path::Class;
use URI;
use URI::Escape;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'spider';
use constant DIR  => '/data/spider/content';

{
  my $dbh = dbh();
  juice($dbh);
  $dbh->disconnect;
}

sub juice {
  my $dbh = shift;

  my $sth = $dbh->prepare( "SELECT url, url_hash, mime FROM spider_page "
     . "WHERE last_visit <> 0 AND mime <> 'text/html'" );
  $sth->execute;
  while ( my $rec = $sth->fetchrow_hashref ) {
    my $file = file DIR, hash2path( $rec->{url_hash} );
    next if -f $file;
    print "$rec->{url} -> $file\n";
    {
      my @body
       = $dbh->selectrow_array(
        "SELECT body FROM spider_page WHERE url_hash=?",
        undef, $rec->{url_hash} );
      if ( length $body[0] ) {
        my $tmp = "$file.tmp";
        $file->parent->mkpath;
        {
          open my $fh, '>', $tmp;
          print $fh $body[0];
          rename $tmp, $file;
        }
        $dbh->do( 'UPDATE spider_page SET body="" WHERE url_hash=?',
          undef, $rec->{url_hash} );
      }
    }
  }
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

