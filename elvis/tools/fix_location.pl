#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Path::Class;
use XML::LibXML::XPathContext;
use XML::LibXML;

use constant ELVIS => dir '/data/newstream/elvis';
use constant HOST  => 'localhost';
use constant USER  => 'root';
use constant PASS  => '';
use constant DB    => 'elvis';

$| = 1;

{
  my $dbh = dbh(DB);

  my $sel = $dbh->prepare(
    join ' ',
    'SELECT i.acno, i.location_id, k.name AS kind',
    'FROM elvis_image AS i, elvis_kind AS k',
    'WHERE k.id=i.kind_id',
    'GROUP BY location_id'
  );
  $sel->execute;
  my %loc = ();
  while ( my $row = $sel->fetchrow_hashref ) {
    my $xml = file( ELVIS, $row->{kind}, $row->{acno} . '.xml' );
    print "$xml\n";
    die "Can't find $xml" unless -f $xml;
    my $doc = do {
      my $fh = $xml->openr;
      $fh->binmode(':encoding(cp1252)');
      local $/;
      <$fh>;
    };
    parse_elvis(
      sub {
        my $info = shift;
        $loc{ $row->{location_id} } = $info->{location};
      },
      $doc
    );

  }

  $dbh->do(
    join( ' ',
      'INSERT INTO elvis_location (id, name) VALUES ',
      join( ', ', map { "( ?, ? )" } keys %loc ) ),
    {},
    %loc
  );

  $dbh->disconnect;
}

sub parse_elvis {
  my ( $cb, $xml ) = @_;
  my $dom = XML::LibXML->load_xml( string => $xml );
  my $xp = XML::LibXML::XPathContext->new($dom);

  for my $img ( $xp->findnodes('/elvisimage') ) {
    $cb->(
      { map { $_->nodeName => $_->textContent } $img->nonBlankChildNodes } );
  }
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

