#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Data::Dumper;
use HTML::LinkExtor;
use URI;

use constant HOST => 'localhost';
use constant USER => 'root';
use constant PASS => '';
use constant DB   => 'elvis';

$| = 1;

use constant GOOGLE_MAP =>
 qr{\Qhttp://maps.google.com/maps?q=\E(-?\d+(?:\.\d+)),(-?\d+(?:\.\d+))};
#use constant NAME => qr{\w+(?:\s+\w+)};
use constant NAME => qr{.*?};
use constant ISH  => qr{roughly|exactly};

use constant KILL => (
  'Click <a target=_blank href=%GOOGLE_MAP%>'
   . 'this link</a> to open a Google Map showing %ISH% (GPS derived) where'
   . '%NAME% was when UPLOADING the picture.',
  'Click <a target=_blank href=%GOOGLE_MAP%>'
   . 'this link</a> to open a Google Map showing %ISH% where'
   . '%NAME% was when UPLOADING the picture.'
);

{
  my $dbh = dbh(DB);

  $dbh->do('TRUNCATE elvis_location');

  my $sel
   = $dbh->prepare( 'SELECT acno, annotation '
     . 'FROM elvis_image '
     . 'WHERE annotation LIKE "%http://%" '
     . 'ORDER BY acno' );
  $sel->execute;

  my @kill = map { mk_re($_) } KILL;

  while ( my $row = $sel->fetchrow_hashref ) {
    my %upd = ();
    my @l   = flatten( get_links( $row->{annotation} ) );
    if ( is_any_google(@l) ) {
      my $annotation = $row->{annotation};
      $annotation =~ s/$_// for @kill;
      if ( $annotation eq $row->{annotation} ) {
        print '<<< ', $row->{annotation}, "\n";
        print ">>> $annotation\n";
      }
      else {
        $dbh->do( 'UPDATE elvis_image SET annotation=? WHERE acno=?',
          {}, $annotation, $row->{acno} );
      }
    }
  }

  $dbh->disconnect;
}

sub mk_re {
  my $pat = shift;
  my ( $lit, @p ) = split /(%\w+%)/, $pat;
  my ( $tok, @re );
  while (@p) {
    push @re, quotemeta($lit);
    ( my ($tok), $lit ) = splice @p, 0, 2;
    die unless $tok =~ /^%(\w+)%$/;
    push @re, eval $1;
  }

  push @re, quotemeta($lit), '\s+';
  my $re = join '', @re;
  return qr{$re};
}

sub is_any_google {
  for my $l (@_) {
    return 1 if is_google($l);
  }
  return;
}

sub is_google {
  my $url = shift;
  return unless $url =~ GOOGLE_MAP;
  return ( $1, $2 );
}

sub flatten {
  my @out;
  for my $ent (@_) {
    my ( undef, %h ) = @$ent;
    push @out, values %h;
  }
  return @out;
}

sub get_links {
  my ($doc) = @_;
  my $p = HTML::LinkExtor->new;
  $p->parse($doc);
  return $p->links;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
