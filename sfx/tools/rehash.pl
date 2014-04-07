#!/usr/bin/env perl

use feature ':5.10';

use strict;
use warnings;
use autodie;

use DBI;
use Data::Dumper;
use Digest::SHA1;
use Path::Class;

use constant SRC  => dir('app/public/asset');
use constant DST  => dir( SRC, 'rehash' );
use constant WORK => dir( SRC, 'work' );
use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'elvis';

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

  my $sel = $dbh->prepare("SELECT DISTINCT(hash) FROM elvis_image");

  my $upd
   = $dbh->prepare("UPDATE elvis_image SET hash = ? WHERE hash = ?");

  $sel->execute;
  while ( my $row = $sel->fetchrow_hashref ) {
    my $src = mk_name( SRC, $row->{hash} );
    die "$src not found" unless -f $src;
    my $tmp = cleanup($src);
    my $sum = hash_file($tmp);
    my $dst = mk_name( DST, $sum );

    print "$src -> $dst\n";

    transaction(
      $dbh,
      sub {
        $upd->execute( $sum, $row->{hash} );
        $dst->parent->mkpath;
        rename $tmp, $dst unless -e $dst;
      }
    );
  }
}

sub cleanup {
  state $seq = 1;
  my $src = shift;
  my $dst = file( WORK, sprintf '%08d.jpg', $seq++ );
  system 'convert', $src, $dst;
  return $dst;
}

sub mk_name {
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

