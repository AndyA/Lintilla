#!/usr/bin/env perl

use v5.10;

use strict;
use warnings;

use DBI;
use Digest::MD5 qw( md5_hex );
use Getopt::Long;
use HTML::LinkExtor;
use JSON;
use LWP::UserAgent;
use Sys::Hostname;
use Time::HiRes;
use URI;

use constant HOST  => 'localhost';
use constant USER  => 'root';
use constant PASS  => '';
use constant DB    => 'spider';
use constant PROXY => 'http://spider.vpn.hexten.net:80/';
use constant BITE  => 10;

my @ROOT = qw(
 http://explore.gateway.bbc.co.uk/ResearchGateway/researchgateway/music1.aspx
 http://explore.gateway.bbc.co.uk/ResearchGateway/researchgateway/tv_and_radio1.aspx
 http://explore.gateway.bbc.co.uk/ResearchGateway/researchgateway/stills_and_photos.aspx
 http://explore.gateway.bbc.co.uk/ResearchGateway/research_gateway_2012/reference.aspx
 http://explore.gateway.bbc.co.uk/ResearchGateway/researchgateway/people.aspx
 http://www.audiencesportal.com/default.aspx
 http://bbcapps2498.national.core.bbc.co.uk/home.aspx
 http://fgbw1wsrot1202.national.core.bbc.co.uk/autorot/
);

$| = 1;

my %INSERT = ();    # defer_insert cache

GetOptions() or die;

my $verb = shift // 'help';

if ( $verb eq 'init' ) {
  my $dbh = dbh(DB);
  reap($dbh);
  for my $root (@ROOT) {
    record_links( $dbh, undef, $root );
  }
  $dbh->disconnect;
}
elsif ( $verb eq 'spider' ) {
  my $dbh = dbh(DB);
  reap($dbh);
  spider($dbh);
  $dbh->disconnect;
}
elsif ( $verb eq 'help' ) {
  print "spider.pl init|spider|help\n";
}
else {
  die "Unknown command: $verb\n";
}

sub start_work {
  my ( $dbh, $count ) = @_;

  my @ids = @{
    $dbh->selectcol_arrayref(
         "SELECT url_hash FROM spider_page "
       . "WHERE worker_id IS NULL "
       . "ORDER BY last_visit, rank LIMIT $count"
    ) };

  update(
    $dbh,
    'spider_page',
    { worker_id    => worker_id(),
      worker_start => time,
    },
    { url_hash => ['IN', \@ids] }
  );

  return @{
    $dbh->selectall_arrayref(
      "SELECT * FROM spider_page WHERE worker_id=?",
      { Slice => {} },
      worker_id()
    ) };
}

sub fill_in {
  my $rec = shift;
  return { %{$rec}, url_hash => md5_hex( $rec->{url} ) };
}

sub end_work {
  my ( $dbh, $rec ) = @_;
  my $frec = fill_in(
    { %$rec,
      last_visit => time,
      worker_id  => undef,
      visits     => ( $rec->{visits} || 0 ) + 1
    }
  );
  update( $dbh, 'spider_page', $frec, { url_hash => $frec->{url_hash} } );
}

sub spider {
  my $dbh   = shift;
  my @queue = @_;

  my $ua = LWP::UserAgent->new;
  $ua->timeout(20);
  my $json = JSON->new->canonical->utf8;
  $ua->proxy( ['http', 'https'], PROXY );

  while ( my @work = start_work( $dbh, BITE ) ) {
    print "Got ", scalar(@work), " jobs\n";
    for my $job (@work) {
      my $url = URI->new( $job->{url} );
      unless ( should_visit($url) ) {
        print "Skipping $url\n";
        end_work(
          $dbh,
          { url     => $job->{url},
            message => 'Skipped by URL based rule',
            code    => 0,
          }
        );
        next;
      }

      print "Fetching $url (rank: $job->{rank})\n";
      my $now     = time;
      my $resp    = $ua->get($url);
      my $elapsed = time - $now;

      my $got = {
        url     => $job->{url},
        code    => $resp->code,
        message => $resp->status_line,
        header  => $json->encode( headers($resp) ),
        body    => $resp->content,
        mime    => scalar( $resp->content_type ),
        elapsed => $elapsed,
      };

      if ( $got->{mime} eq 'text/html' ) {
        record_links( $dbh, $job, find_links($resp) );
      }

      end_work( $dbh, $got );

      print sprintf "%s (elapsed: %d, type: %s)\n", $resp->status_line,
       $elapsed, $got->{mime};
    }
  }
}

sub clean_url {
  my $url = shift;
  $url->fragment(undef);
  return $url;
}

sub find_links {
  my $resp = shift;

  my @links = ();

  HTML::LinkExtor->new(
    sub {
      my ( $tag, %attr ) = @_;
      return if $tag ne 'a';
      my $href = $attr{href};
      push @links, $href
       unless $href =~ /^\w+:/ && $href !~ /^https?:/;
    }
  )->parse( $resp->content );

  my $base = $resp->base;
  return map { clean_url( URI->new_abs( $_, $base ) ) } @links;
}

sub headers {
  my $resp = shift;
  return { map { $_ => [$resp->header($_)] } $resp->header_field_names };
}

sub worker_id { join '.', hostname, $$ }

sub should_visit {
  my $url = shift;
  my $host = eval { $url->host };
  if ($@) {
    warn "$@";
    return;
  }
  return unless $host =~ /\.bbc\.co\.uk$/;
  return if $host eq 'www.bbc.co.uk';
  return if $host eq 'news.bbc.co.uk';
  return if $host eq 'm.bbc.co.uk';
  return if $host eq 'genome.ch.bbc.co.uk';
  return if $host eq 'ssl.bbc.co.uk';
  return if $host eq 'iplayerhelp.external.bbc.co.uk';
  return if $host eq 'elvis.nca.bbc.co.uk';
  return if $host =~ /\bbetsie\b/;
  return 1;
}

sub reap {
  my $dbh     = shift;
  my $hn      = hostname;
  my @workers = @{
    $dbh->selectcol_arrayref(
      'SELECT DISTINCT(worker_id) FROM spider_page WHERE worker_id IS NOT NULL'
    ) };
  for my $worker (@workers) {
    next unless $worker =~ /^\Q$hn.\E(\d+)$/;
    my $pid = $1;
    next if kill 0, $pid;
    print "Reaping jobs for $worker\n";
    update(
      $dbh, 'spider_page',
      { worker_start => undef, worker_id => undef },
      { worker_id    => $worker }
    );
  }
}

sub uniq {
  my %seen = ();
  return grep { !$seen{$_}++ } @_;
}

sub record_links {
  my ( $dbh, $job, @links ) = @_;

  return unless @links;

  print "Recording ", scalar(@links), " links\n";

  my $now = time;

  my ( $url_hash, $rank )
   = $job ? ( md5_hex( $job->{url} ), $job->{rank} + 1 ) : ( undef, 0 );

  my @parts = map {
    [ '(?, ?, ?)',
      [$_->[1], $url_hash, $now],
      '(?, ?, ?, ?)',
      [@$_, $rank, 0],
    ]
  } map { [$_, md5_hex($_)] } uniq(@links);

  retry(
    $dbh,
    sub {
      if ($job) {
        $dbh->prepare('DELETE FROM `spider_via` WHERE `via_hash` = ?')
         ->execute($url_hash);

        $dbh->prepare(
          'INSERT INTO `spider_via` (`url_hash`, `via_hash`, `last_visit`) VALUES '
           . join( ', ', map { $_->[0] } @parts ) )
         ->execute( map { @{ $_->[1] } } @parts );
      }

      $dbh->prepare(
        'INSERT INTO `spider_page` (`url`, `url_hash`, `rank`, `last_visit`) VALUES '
         . join( ', ', map { $_->[2] } @parts )
         . 'ON DUPLICATE KEY UPDATE `rank`=IF(`rank` > ?, ?, `rank`)' )
       ->execute( ( map { @{ $_->[3] } } @parts ), $rank, $rank );
    },
    10
  );
}

sub trim {
  my $s = shift;
  s/^\s+//, s/\s+$// for $s;
  return $s;
}

sub retry {
  my ( $dbh, $cb, $tries ) = @_;
  my $sleep = 1;
  while () {
    die "No more retries\n" if $tries-- <= 0;
    eval { transaction( $dbh, $cb ) };
    last unless $@;
    warn "$@";
    Time::HiRes::sleep($sleep);
    $sleep *= 1.414;
    print "Retrying...\n";
  }
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

sub extended_insert {
  my ( $dbh, $ins ) = @_;
  for my $tbl ( keys %$ins ) {
    for my $flds ( keys $ins->{$tbl} ) {
      my @k = split /:/, $flds;
      my @sql
       = ( "INSERT INTO `$tbl` (", join( ', ', map "`$_`", @k ), ") VALUES " );
      my $vc = '(' . join( ', ', map '?', @k ) . ')';
      my @data = @{ $ins->{$tbl}{$flds} };
      push @sql, join ', ', ($vc) x @data;
      my $sql = join '', @sql;
      my @bind = map @$_, @data;
      dump_sql( $sql, @bind );
      my $sth = $dbh->prepare($sql);
      $sth->execute(@bind);
    }
  }
}

sub insert {
  my ( $dbh, $tbl, $rec ) = @_;
  my @k = sort keys %$rec;
  my $ins = { $tbl => { join( ':', @k ) => [[@{$rec}{@k}]] } };
  extended_insert( $dbh, $ins );
}

sub flush_pending {
  my $dbh = shift;
  my $ins = {%INSERT};
  %INSERT = ();
  $dbh->do('START TRANSACTION');
  eval { extended_insert( $dbh, $ins ) };
  if ( my $err = $@ ) {
    $dbh->do('ROLLBACK');
    die $err;
  }
  $dbh->do('COMMIT');
}

sub defer_insert {
  my ( $dbh, $tbl, $rec ) = @_;

  my @k = sort keys %$rec;
  my $k = join ':', @k;
  push @{ $INSERT{$tbl}{$k} }, [@{$rec}{@k}];
}

sub make_where {
  my $sel = shift;
  my ( @bind, @term );
  for my $k ( sort keys %$sel ) {
    my $v = $sel->{$k};
    my ( $op, $vv )
     = 'ARRAY' eq ref $v ? @$v : ( ( defined $v ? '=' : 'IS' ), $v );
    if ( 'ARRAY' eq ref $vv ) {
      push @term, "`$k` $op (" . join( ', ', map '?', @$vv ) . ")";
      push @bind, @$vv;
    }
    else {
      push @term, "`$k` $op ?";
      push @bind, $vv;
    }
  }
  @term = ('TRUE') unless @term;
  return ( join( ' AND ', @term ), @bind );
}

sub update {
  my ( $dbh, $tbl, $rec, $sel, $ord ) = @_;

  my ( @fld, @bind );
  while ( my ( $k, $v ) = each %$rec ) {
    push @fld,  $k;
    push @bind, $v;
  }

  my $limit = delete $sel->{LIMIT};
  my ( $where, @wbind ) = make_where($sel);

  my $sql
   = "UPDATE `$tbl` SET "
   . join( ', ', map "`$_`=?", @fld )
   . " WHERE $where";

  $sql .= ' ORDER BY ' . join ', ',
   map { /^-(.+)/ ? "`$1` DESC" : "`$_` ASC" } @$ord
   if $ord;

  $sql .= " LIMIT $limit" if defined $limit;

  $dbh->prepare($sql)->execute( @bind, @wbind );
}

sub execute_select {
  my ( $dbh, $tbl, $sel, $cols, $ord ) = @_;

  my ( $sql, @bind ) = make_select( $tbl, $sel, $cols, $ord );
  #  print show_sql( $sql, @bind ), "\n";
  my $sth = $dbh->prepare($sql);
  $sth->execute(@bind);
  return $sth;
}

sub make_select {
  my ( $tbl, $sel, $cols, $ord ) = @_;

  my $limit = delete $sel->{LIMIT};
  my ( $where, @bind ) = make_where($sel);

  my @sql = (
    'SELECT',
    ( $cols ? join ', ', map "`$_`", @$cols : '*' ),
    "FROM `$tbl` WHERE ", $where
  );

  if ($ord) {
    push @sql, "ORDER BY", join ', ',
     map { /^-(.+)/ ? "`$1` DESC" : "`$_` ASC" } @$ord;
  }

  if ( defined $limit ) {
    push @sql,  'LIMIT ?';
    push @bind, $limit;
  }

  return ( join( ' ', @sql ), @bind );
}

sub show_sql {
  my ( $sql, @bind ) = @_;
  my $next = sub {
    my $val = shift @bind;
    return 'NULL' unless defined $val;
    return $val if $val =~ /^\d+(?:\.\d+)?$/;
    $val =~ s/\\/\\\\/g;
    $val =~ s/\n/\\n/g;
    $val =~ s/\t/\\t/g;
    return "'$val'";
  };
  $sql =~ s/\?/$next->()/eg;
  return $sql;
}

sub dbh {
  my $db = shift;
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $db, HOST ),
    USER, PASS, { RaiseError => 1 } );
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

