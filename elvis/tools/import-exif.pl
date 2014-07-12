#!/usr/bin/env perl

use strict;
use warnings;

use Path::Class;
use DBI;
use Data::Dumper;
use File::Find;
use JSON;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'elvis';

$| = 1;

{
  my $dbh = dbh(DB);

  find {
    wanted => sub {
      return unless /\.json$/;
      import( $dbh, $_ );
    },
    no_chdir => 1
  }, @ARGV;

  $dbh->disconnect;
}

sub import {
  my ( $dbh, $json ) = @_;
  my $doc = JSON->new->decode( scalar file($json)->slurp );
  for my $img (@$doc) {
    my $src = $img->{SourceFile};
    die unless defined $src;
    my $hash = hash_from_file($src);
    die unless defined $hash;
    my @ids = @{
      $dbh->selectcol_arrayref( 'SELECT acno FROM elvis_image WHERE hash=?',
        {}, $hash ) };
    print join( ', ', @ids ), "\n";
    my $sql = join ' ',
     'INSERT INTO elvis_exif (acno, exif) VALUES',
     join( ', ', map { "(?, ?)" } @ids );
    my $exif = JSON->new->utf8->encode($img);
    my $rows = $dbh->do( $sql, {}, map { ( $_, $exif ) } @ids );
    print "$hash : $rows\n";
  }
}

sub hash_from_file {
  my $src = shift;
  $src =~ s/\.\w+$//;
  my @p = split /\//, $src;
  my $hash = '';
  $hash = ( pop @p ) . $hash while length $hash < 40;
  return unless length $hash == 40 && $hash =~ /^[0-9a-f]+$/i;
  return $hash;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
