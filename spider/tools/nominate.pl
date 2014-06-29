#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use DBI;
use Digest::MD5 qw( md5_hex );
use Path::Class;
use Try::Tiny;
use URI::Escape;
use URI;

use constant HOST    => 'localhost';
use constant USER    => 'root';
use constant PASS    => '';
use constant DB      => 'spider';
use constant BY_HASH => '/data/spider/content';
use constant BY_NAME => '/data/spider/attachments';

{
  my $dbh = dbh();
  nominate($dbh);
  $dbh->disconnect;
}

sub nominate {
  my $dbh = shift;
  my @err = ();

  my $sth = $dbh->prepare( "SELECT url, url_hash, mime FROM spider_page "
     . "WHERE last_visit <> 0 AND mime <> 'text/html'" );
  $sth->execute;
  while ( my $rec = $sth->fetchrow_hashref ) {
    my $hash = file BY_HASH, hash2path( $rec->{url_hash} );
    my @n = uri2path( $rec->{url} );
    $n[-1] = join ' ', $rec->{url_hash}, $n[-1];
    my $name = file BY_NAME, @n;
    next unless -f $hash;
    next if -f $name;
    print "$rec->{url} -> $name\n";
    try {
      $name->parent->mkpath;
      link $hash, $name;
    }
    catch {
      my $err = $_;
      push @err, $err;
      warn "$err\n";
    };
  }
  if (@err) {
    print "\nErrors:\n";
    print "  $_\n" for @err;
  }
}

sub safe {
  my $name = shift;
  $name =~ s/[\/\\:]/_/g;
}

sub uri2path {
  my $uri = URI->new(shift);
  my @p = ( $uri->host, grep { $_ ne '..' } split /\//, $uri->path );
  push @p, 'index' if @p < 2;
  return @p;
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
