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
use Path::Class;
use Sys::Hostname;
use Time::HiRes;
use URI;

$| = 1;

my %O      = ();
my %INSERT = ();    # defer_insert cache

GetOptions() or die syntax();

die syntax() unless @ARGV >= 2;

my ( $verb, $config ) = ( shift, shift );

my $Config
 = localise( JSON->new->decode( scalar file($config)->slurp ) );
my @Watch = ( $0, $config );

my %action = (
  help => sub { print syntax() },
  init => sub {
    reap();
    record_links( undef, @{ $Config->{job}{root} } );
  },
  spider => sub {
    reap();
    spider();
  },
);

die "Unknown verb: $verb\n" unless $action{$verb};

$action{$verb}->();

exit;

sub file_changed {
  for (@_) {
    return 1 if -M $_ < 0;
  }
  return;
}

sub should_stop {
  return file_changed(@Watch);
}

sub start_work {
  my $count = shift;
  my $dbh   = dbh();

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

  my @got = @{
    $dbh->selectall_arrayref(
      "SELECT * FROM spider_page WHERE worker_id=?",
      { Slice => {} },
      worker_id()
    ) };

  $dbh->disconnect;
  return @got;
}

sub fill_in {
  my $rec = shift;
  return { %{$rec}, url_hash => md5_hex( $rec->{url} ) };
}

sub end_work {
  my $rec  = shift;
  my $frec = fill_in(
    { %$rec,
      last_visit => time,
      worker_id  => undef,
      visits     => ( $rec->{visits} || 0 ) + 1
    }
  );
  my $dbh = dbh();
  update( $dbh, 'spider_page', $frec, { url_hash => $frec->{url_hash} } );
  $dbh->disconnect;
}

sub spider {
  my @queue = @_;

  my $ua = LWP::UserAgent->new( keep_alive => 10 );
  $ua->timeout(20);
  my $should_visit = mk_should_visit( $Config->{job} );

  my $json = JSON->new->canonical->utf8;
  $ua->proxy( ['http', 'https'], $Config->{proxy} )
   if defined $Config->{proxy};
  until ( should_stop() ) {
    my @work = start_work( $Config->{bite} );
    print "Got ", scalar(@work), " jobs\n";
    for my $job (@work) {
      my $url = URI->new( $job->{url} );
      unless ( $should_visit->($url) ) {
        print "Skipping $url\n";
        end_work(
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

      my $got = fill_in(
        { url     => $job->{url},
          code    => $resp->code,
          message => $resp->status_line,
          header  => $json->encode( headers($resp) ),
          body    => $resp->content,
          mime    => scalar( $resp->content_type ),
          elapsed => $elapsed,
        }
      );

      if ( $got->{mime} eq 'text/html' ) {
        record_links( $job, find_links($resp) );
      }
      else {
        detach($got);
      }

      end_work($got);

      print sprintf "%s (elapsed: %d, type: %s)\n", $resp->status_line,
       $elapsed, $got->{mime};
    }
  }
  print "Stopping...\n\n";
}

sub detach {
  my $rec = shift;
  my $file = file $Config->{job}{stash}, hash2path( $rec->{url_hash} );
  print "$rec->{url} -> $file\n";
  my $tmp = "$file.tmp";
  $file->parent->mkpath;
  {
    open my $fh, '>', $tmp;
    print $fh $rec->{body};
    rename $tmp, $file;
  }
  $rec->{body} = '';
}

sub hash2path {
  my $hash = shift;
  die unless $hash =~ /^(..)(..)(.+)$/;
  return ( $1, $2, $3 );
}

sub clean_url {
  my $url = shift;
  $url->fragment(undef);
  ( my $path = $url->path ) =~ s/;jsessionid=[0-9a-fA-F]+$//g;
  $url->path($path);
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
  return uniq( map { clean_url( URI->new_abs( $_, $base ) ) } @links );
}

sub headers {
  my $resp = shift;
  return { map { $_ => [$resp->header($_)] } $resp->header_field_names };
}

sub worker_id { join '.', hostname, $$ }

sub glob2re {
  my $re = join '',
   map { $_ eq '*' ? '.*?' : $_ eq '?' ? '.' : quotemeta($_) }
   split //, shift;
  return qr/^$re$/;
}

sub mk_in_list {
  my @re = map { glob2re($_) } @_;
  return sub {
    for (@re) { return 1 if $_[0] =~ $_ }
    return;
  };
}

sub mk_should_visit {
  my $job          = shift;
  my $limit        = mk_in_list( @{ $job->{limit} } );
  my $exclude      = mk_in_list( @{ $job->{exclude} } );
  my $exclude_host = mk_in_list( @{ $job->{exclude_host} } );
  return sub {
    my $url = shift;
    return if $exclude->($url);
    my $host = eval { $url->host };
    if ($@) {
      warn "$@";
      return;
    }
    return unless $limit->($host);
    return if $exclude_host->($host);
    return 1;
  };
}

sub reap {
  my $dbh     = dbh();
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
  $dbh->disconnect;
}

sub uniq {
  my %seen = ();
  return grep { !$seen{$_}++ } @_;
}

sub record_links {
  my ( $job, @links ) = @_;

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

  my $dbh = dbh();

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
  $dbh->disconnect();
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

sub localise {
  my $cfg = shift;
  return { %$cfg, %{ $cfg->{per_host}{ hostname() } || {} } };
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
  my $cfg = $Config->{db};
  return DBI->connect(
    sprintf( 'DBI:mysql:database=%s;host=%s', $cfg->{db}, $cfg->{host} ),
    $cfg->{user},
    $cfg->{pass},
    { RaiseError => 1, mysql_auto_reconnect => 1 }
  );
}

sub syntax {
  return <<EOT
Syntax: spider <verb> <config.json>

Verbs: init spider help
EOT
}

# vim:ts=2:sw=2:sts=2:et:ft=perl

