#!/usr/bin/env perl

use feature ':5.10';

use strict;
use warnings;
use autodie;

use DBI;
use Data::Dumper;
use Digest::SHA1;
use Path::Class;

use constant SRC     => dir('/data/newstream/elvis');
use constant DST     => dir('/data/newstream/lintilla/app/public/asset');
use constant WORK    => dir('/data/newstream/elvis.tmp');
use constant HOST    => 'localhost';
use constant USER    => 'root';
use constant PASS    => '';
use constant DB      => 'elvis';
use constant CLEANUP => 0;

$| = 1;

WORK->mkpath;

{
  my $dbh = dbh(DB);

  hash( $dbh, SRC );

  $dbh->disconnect;
}

WORK->rmtree;

sub hash {
  my ( $dbh, $root ) = @_;

  my $sel
   = $dbh->prepare( "SELECT k.name AS kind, i.acno "
     . "FROM elvis_image AS i, elvis_kind AS k "
     . "WHERE i.kind_id = k.id AND i.hash IS NULL" );

  my $upd
   = $dbh->prepare("UPDATE elvis_image SET hash = ? WHERE acno = ?");

  $sel->execute;
  while ( my $row = $sel->fetchrow_hashref ) {
    my $src = mk_src_name( SRC, $row->{kind}, $row->{acno} );
    die "$src not found" unless -f $src;
    my $tmp = CLEANUP ? cleanup($src) : $src;
    my $sum = hash_file($tmp);
    my $dst = mk_dst_name( DST, $sum );
    say "$src -> $dst";

    transaction(
      $dbh,
      sub {
        $upd->execute( $sum, $row->{acno} );
        $dst->parent->mkpath;
        ( CLEANUP ? rename $tmp, $dst : link $tmp, $dst ) unless -e $dst;
      }
    );
  }
}

sub cleanup {
  state $seq = 1;
  my $src = shift;
  say "cleanup $src";
  my $dst = file( WORK, sprintf '%08d.jpg', $seq++ );
  system 'convert', $src, $dst;
  return $dst;
}

sub mk_src_name {
  my ( $root, $kind, $id ) = @_;
  return file( $root, $kind, "$id.jpg" );
}

sub mk_dst_name {
  my ( $root, $hash ) = @_;
  my @path = $hash =~ /^(...)(...)(.+)$/;
  $path[-1] .= '.jpg';
  return file( $root, @path );
}

sub hash_file {
  my $obj = shift;
  open my $fh, '<', $obj;
  return Digest::SHA1->new->addfile($fh)->hexdigest;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

sub transaction {
  my ( $dbh, $cb ) = @_;
  $dbh->do('START TRANSACTION');
  eval { $cb->() };
  if ( my $err = $@ ) {
    $dbh->do('ROLLBACK');
    die $err;
  }
  $dbh->do('COMMIT');
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

