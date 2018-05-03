#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Data::Dumper;
use File::Find;
use JSON;
use Memoize;
use Path::Class;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'elvis';

memoize 'ref_data';

$| = 1;

{
  my $dbh = dbh(DB);

  my $sel = $dbh->prepare('SELECT acno, exif FROM elvis_exif');
  $sel->execute;
  while ( my $row = $sel->fetchrow_hashref ) {
    my $exif = JSON->new->utf8->decode( $row->{exif} );
    next unless exists $exif->{Keywords} && 'ARRAY' eq ref $exif->{Keywords};
    print $row->{acno}, "\n";
    my %seen = ();
    for my $kw ( @{ $exif->{Keywords} } ) {
      next if $seen{ lc $kw }++;
      my $kw_id = ref_data( $dbh, 'elvis_keyword', $kw );
      printf "  %8d: %s\n", $kw_id, $kw;
      insert( $dbh, 'elvis_image_keyword',
        { id => $kw_id, acno => $row->{acno} } );
    }
  }

  $dbh->disconnect;
}

sub ref_data {
  my ( $dbh, $tbl, $value ) = @_;
  return undef unless defined $value && length $value;
  my ( $sql, @bind ) = make_select( $tbl, { name => $value }, ['id'] );
  my ($id) = $dbh->selectrow_array( $sql, {}, @bind );
  return $id if defined $id;
  insert( $dbh, $tbl, { name => $value } );
  return $dbh->last_insert_id( undef, undef, $tbl, 'id' );
}

sub insert {
  my ( $dbh, $tbl, $rec ) = @_;
  my @k = sort keys %$rec;
  my $sql
   = "INSERT INTO `$tbl` ("
   . join( ', ', map "`$_`", @k )
   . ") VALUES ("
   . join( ', ', map '?', @k ) . ")";
  my $sth = $dbh->prepare($sql);
  $sth->execute( @{$rec}{@k} );
}

sub make_where {
  my $sel = shift;
  my ( @bind, @term );
  for my $k ( sort keys %$sel ) {
    my $v = $sel->{$k};
    my ( $op, $vv ) = 'ARRAY' eq ref $v ? @$v : ( '=', $v );
    push @term, "`$k` $op ?";
    push @bind, $vv;
  }
  @term = ('TRUE') unless @term;
  return ( join( ' AND ', @term ), @bind );
}

sub make_select {
  my ( $tbl, $sel, $cols ) = @_;

  my ( $where, @bind ) = make_where($sel);

  my @sql = (
    'SELECT',
    ( $cols ? join ', ', map "`$_`", @$cols : '*' ),
    "FROM `$tbl` WHERE ", $where
  );

  return ( join( ' ', @sql ), @bind );
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
