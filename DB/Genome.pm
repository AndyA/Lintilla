package Lintilla::DB::Genome;

use v5.10;

use Dancer ':syntax';
use HTML::Tiny;
use Lintilla::DB::Genome::Search;
use Lintilla::Filter qw( cook );
use Moose;
use POSIX qw( strftime );

=head1 NAME

Lintilla::DB::Genome - Genome model

=cut

use constant YEAR_START => 1923;
use constant YEAR_END   => 2009;

with 'Lintilla::Role::DB';
with 'Lintilla::Role::Gatherer';

has source => (
  is       => 'ro',
  required => 1,
  default  => '70ba6e0c-c493-42bd-8c64-c9f4be994f6d',
);

has years    => ( is => 'ro', lazy => 1, builder => '_build_years' );
has decades  => ( is => 'ro', lazy => 1, builder => '_build_decades' );
has services => ( is => 'ro', lazy => 1, builder => '_build_services' );

my @DAY = qw(
 SUN MON TUE WED
 THU FRI SAT
);

my @MONTH = qw(
 January   February March    April
 May       June     July     August
 September October  November December
);

sub unique(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

sub _build_services {
  my $self = shift;
  my $sql  = join ' ',
   'SELECT * FROM `genome_002`.`genome_services` ',
   'WHERE `_parent` IS NULL ',
   'ORDER BY `order` IS NULL, `order` ASC, `title` ASC';

  return $self->group_by(
    $self->dbh->selectall_arrayref( $sql, { Slice => {} } ), 'type' );
}

sub _build_years {
  shift->dbh->selectcol_arrayref(
    'SELECT DISTINCT `year` FROM `genome_programmes_v2`'
     . ' WHERE `year` BETWEEN ? AND ? ORDER BY `year`',
    {}, YEAR_START, YEAR_END
  );
}

sub _build_decades {
  my $self = shift;
  my %dec  = ();
  $dec{ int( $_ / 10 ) * 10 }++ for @{ $self->years };
  return [sort { $a <=> $b } keys %dec];
}

# If @years is supplied it's a list of hashes each of which contain a
# year key.
sub _decade_years {
  my ( $self, $first, $last, @years ) = @_;

  @years = map { { year => $_ } } ( $first .. $last ) unless @years;
  my %byy = map { $_->{year} => $_ } @years;

  my ( $fd, $ld ) = map { 10 * int( $_ / 10 ) } ( $first, $last );
  my @dy = ();
  for ( my $decade = $fd; $decade <= $ld; $decade += 10 ) {
    push @dy,
     {decade => sprintf( '%02d', $decade % 100 ),
      years => [map { $byy{$_} } ( $decade .. $decade + 9 )] };
  }
  return \@dy;
}

sub month_names { \@MONTH }

sub short_month_names {
  return [map { substr $_, 0, 3 } @MONTH];
}

sub decade_years {
  my $self = shift;
  return $self->_decade_years( YEAR_START, YEAR_END );
}

sub service_years {
  my ( $self, $service ) = @_;

  my $rs = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT DISTINCT(`year`), MIN(`date`) AS `first`',
      'FROM genome_service_dates',
      'WHERE `service`=?',
      'GROUP BY `year`',
      'ORDER BY `date`' ),
    { Slice => {} },
    $service
  );

  return $self->_decade_years( YEAR_START, YEAR_END, @$rs );
}

sub service_months {
  my ( $self, $service, $year ) = @_;

  my $rs = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT DISTINCT(`month`), MIN(`date`) AS `first`',
      'FROM genome_service_dates',
      'WHERE `service`=?',
      'AND `year`=?',
      'GROUP BY `month`',
      'ORDER BY `date`' ),
    { Slice => {} },
    $service, $year
  );

  my %bym
   = map { $_->{month} => { %$_, name => $MONTH[$_->{month} - 1] } } @$rs;

  return [map { $bym{$_} } ( 1 .. 12 )];
}

sub day_for_date {
  my ( $self, $tm ) = @_;
  my @tm = gmtime( $tm // 0 );
  return ( day => $DAY[$tm[6]], mday => $tm[3] );
}

sub service_proximate_days {
  my ( $self, $service, $date, $span ) = @_;

  my $rs = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `date`,',
      ' TO_DAYS(`date`) * 86400 - 62167219200 AS `epoch`, ',
      ' DATEDIFF(`date`, ?) AS `offset`',
      'FROM genome_service_dates',
      'WHERE service = ?',
      'AND `date` BETWEEN DATE_SUB(?, INTERVAL ? DAY) AND DATE_ADD(?, INTERVAL ? DAY)',
      'ORDER BY `date`' ),
    { Slice => {} },
    $date, $service, $date, $span, $date, $span
  );

  my %ent = map { $_->{offset} => $_ } map {
    { %$_, $self->day_for_date( $_->{epoch}, ) }
  } @$rs;

  return [
    map {
      { %{ $ent{$_} || {} }, offset => $_ }
    } ( -$span .. $span )
  ];
}

=head2 Dynamic Data

=cut

sub service_defaults {
  my ( $self, $service, @got ) = @_;
  my $sql = join ' ',
   'SELECT sd.date, s._uuid, s.has_outlets, s.default_outlet',
   'FROM genome_service_dates AS sd, genome_services AS s',
   'WHERE sd.service=s._uuid AND s._key=?',
   'ORDER BY date LIMIT 1';
  my $rec = $self->dbh->selectrow_hashref( $sql, {}, $service );
  return unless defined $rec;

  # Simple case
  return ( $rec->{date} ) unless $rec->{has_outlets} eq 'Y';

  if ( @got < 1 ) {
    # Find default outlet
    my $outlet = join ' ',
     'SELECT subkey FROM genome_services',
     'WHERE _uuid=?';
    my $orec
     = $self->dbh->selectrow_hashref( $outlet, {}, $rec->{default_outlet} );
    push @got, $orec->{subkey};
  }

  push @got, $rec->{date} if @got < 2;
  return @got;
}

sub resolve_service {
  my ( $self, $service, @spec ) = @_;

  my $idx = $self->is_uuid($service) ? '_uuid' : '_key';
  my $rec = $self->dbh->selectrow_hashref(
    join( ' ',
      'SELECT *', 'FROM genome_services',
      "WHERE $idx=?", 'LIMIT 1' ),
    {},
    $service
  );

  my $uuid  = $rec->{'_uuid'};
  my @title = ( $rec->{'title'} );
  my @path  = ( $rec->{'_key'} );
  if ( $rec->{has_outlets} && $rec->{has_outlets} eq 'Y' ) {
    my ( $ff, $vv )
     = @spec ? ( subkey => $spec[0] ) : ( _uuid => $rec->{default_outlet} );
    my $outlet
     = $self->dbh->selectrow_hashref(
      "SELECT * FROM genome_services WHERE _parent=? AND $ff=?",
      {}, $rec->{_uuid}, $vv );
    die unless $outlet;
    $rec->{outlet} = $outlet;
    $uuid = $outlet->{_uuid};
    push @title, $outlet->{title};
    push @path,  $outlet->{subkey};
  }

  return {
    svc         => $self->_make_public($rec),
    uuid        => $uuid,
    type        => $rec->{type},
    short_title => $rec->{title},
    title       => join( ' ', @title ),
    path        => join( '/', @path ),
    began       => $self->_pretty_date( $rec->{began} ),
    ended       => $self->_pretty_date( $rec->{ended} ),
  };
}

sub resolve_services {
  my $self = shift;
  my $rec  = $self->resolve_service(@_);
  my $svc  = $rec->{svc};
  for my $key ( 'preceded_by', 'succeeded_by' ) {
    if ( defined( my $uuid = $svc->{$key} ) ) {
      $svc->{$key} = $self->resolve_service($uuid);
    }
  }
  return $rec;
}

sub decode_date {
  my ( $self, $date ) = @_;
  die unless $date =~ /^(\d+)-(\d+)-(\d+)/;
  return ( $1, $2, $3 );
}

sub decode_time {
  my ( $self, $time ) = @_;
  die unless $time =~ /(\d+):(\d+):(\d+)$/;
  return ( $1, $2, $3 );
}

sub clean_id {
  my ( $self, $uuid ) = @_;
  $uuid =~ s/-//g;
  return $uuid;
}

sub _add_programme_details {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;
  my $sql
   = 'SELECT * FROM genome_contributors WHERE _parent IN ('
   . join( ', ', map '?', @uids )
   . ') ORDER BY _parent, `index` ASC';
  my $contrib
   = $self->dbh->selectall_arrayref( $sql, { Slice => {} }, @uids );
  my %by_parent = ();
  for my $co (@$contrib) {
    $co->{type} //= 'Unknown';
    push @{ $by_parent{ $co->{_parent} } }, $co;
  }
  for my $row (@$rows) {
    $row->{contrib} = $by_parent{ $row->{_uuid} } || [];
    $row->{time} = sprintf '%d.%02d', $self->decode_time( $row->{when} );
    $row->{link} = $self->clean_id( $row->{_uuid} );
    $row->{pretty_date}
     = $self->_pretty_date( @{$row}{ 'year', 'month', 'day' } );
  }
  return $rows;
}

sub _issue_key {
  my ( $self, $issue ) = @_;
  return $issue->{default_child_key}
   if defined $issue->{default_child_key};
  return $issue->{_key};
}

sub _issue_id {
  my ( $self, $issue ) = @_;
  return $issue->{default_child}
   if defined $issue->{default_child};
  return $issue->{_uuid};
}

sub _issue_pdf_path {
  my ( $self, $issue ) = @_;
  my $key = $self->_issue_key($issue);
  return join '/', $issue->{decade}, $issue->{year}, $key, $key . '.pdf';
}

sub _issue_image_path {
  my ( $self, $issue ) = @_;
  my $key = $self->_issue_key($issue);
  return join '/', $issue->{decade}, $issue->{year}, $key, $key . '-0.png';
}

sub _make_public {
  my ( $self, $in ) = @_;
  my $out = {};
  while ( my ( $k, $v ) = each %$in ) {
    ( my $kk = $k ) =~ s/^_+//g;
    $out->{$kk} = $v;
  }
  return $out;
}

sub _child_fold {
  my ( $self, $hash ) = @_;

  if ( 'ARRAY' eq ref $hash ) {
    $self->_child_fold($_) for @$hash;
    return $hash;
  }

  while ( my ( $k, $V ) = each %$hash ) {
    my $ck = "child_$k";
    $hash->{$k} //= $hash->{$ck};
  }
  return $hash;
}

sub _cook_issues {
  my ( $self, $issues ) = @_;

  return cook issues => [
    map {
      {
        %{ $self->_make_public($_) },
         link              => $self->_issue_id($_),
         path              => $self->_issue_image_path($_),
         pdf               => $self->_issue_pdf_path($_),
         month_name        => $MONTH[$_->{month} - 1],
         pretty_date       => $self->_pretty_date( $_->{date} ),
         pretty_start_date => $self->_pretty_date( $_->{start_date} ),
         short_start_date  => $self->_short_date( $_->{start_date} ),
         pretty_end_date   => $self->_pretty_date( $_->{end_date} ),
      }
    } @$issues
  ];
}

sub issues {
  my ( $self, @uuid ) = @_;

  return $self->_cook_issues(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_issues',
        'WHERE _uuid IN (',
        join( ', ', map '?', @uuid ),
        ')' ),
      { Slice => {} },
      @uuid
    )
  );
}

sub annual_issues {
  my $self = shift;

  return (
    issues => $self->group_by(
      $self->_cook_issues(
        $self->dbh->selectall_arrayref(
          join( ' ',
            'SELECT *',
            'FROM genome_issues ',
            "WHERE approved_year='Y'",
            'AND _parent IS NULL',
            'ORDER BY `year`' ),
          { Slice => {} }
        )
      ),
      'decade'
    )
  );
}

sub _short_date {
  my ( $self, $y, $m, $d ) = @_;
  return undef unless defined $y;
  ( $y, $m, $d ) = $self->decode_date($y) unless defined $m;
  return sprintf '%02d %s', $d, lc substr $MONTH[$m - 1], 0, 3;
}

sub _pretty_date {
  my ( $self, $y, $m, $d ) = @_;
  return undef unless defined $y;
  ( $y, $m, $d ) = $self->decode_date($y) unless defined $m;
  ( my $pd = strftime( "%d %B %Y", 0, 0, 0, $d, $m - 1, $y - 1900 ) )
   =~ s/^0//;
  return $pd;
}

sub _build_service_spiel {
  my ( $self, $rec ) = @_;
  my %case = ( tv => 'television', radio => 'radio' );
  my $svc  = $rec->{svc};
  my @para = ();

  {
    my @spiel
     = ( $rec->{short_title}, 'is a', $case{ $svc->{type} }, 'service' );
    my @dates = ();
    push @dates, 'began broadcasting on ' . $rec->{began}
     if defined $rec->{began};
    push @dates, 'ended on ' . $rec->{ended} if defined $rec->{ended};
    push @spiel, 'which', join( ' and ', @dates ) if @dates;
    push @para, join( ' ', @spiel ) . '.';
  }

  {
    my @others = ();
    my $h      = HTML::Tiny->new;
    push @others,
     'replaced '
     . $h->a( { href => '/schedules/' . $svc->{preceded_by}{path} },
      $svc->{preceded_by}{title} )
     if defined $svc->{preceded_by};
    push @others,
     'was replaced by '
     . $h->a( { href => '/schedules/' . $svc->{succeeded_by}{path} },
      $svc->{succeeded_by}{title} )
     if defined $svc->{succeeded_by};
    push @para, 'It ' . join( ' and ', @others ) . '.' if @others;
  }

  return join ' ', @para;
}

sub listing_for_schedule {
  my ( $self, @spec ) = @_;

  my $date = pop @spec;
  my ( $year, $month, $day ) = $self->decode_date($date);

  my $rec = $self->resolve_services(@spec);
  my ( $svc, $service, $type, $short_title, $title )
   = @{$rec}{qw( svc uuid type short_title title )};

  my $sql = join ' ',
   'SELECT * FROM genome_programmes_v2',
   'WHERE `source` = ?',
   'AND `service` = ?',
   'AND `date` = ?',
   'ORDER BY `when` ASC';

  my $rows = $self->dbh->selectall_arrayref( $sql, { Slice => {} },
    $self->source, $service, $date );

  my @pages  = unique map { $_->{page} } @$rows;
  my @issues = unique map { $_->{issue} } @$rows;

  return (
    about          => $rec,
    spiel          => $self->_build_service_spiel($rec),
    day            => $day,
    issues         => $self->issues(@issues),
    listing        => $self->_add_programme_details($rows),
    month          => $month,
    month_name     => $MONTH[$month - 1],
    outlet         => join( '/', @spec ),
    pages          => \@pages,
    pretty_date    => $self->_pretty_date( $year, $month, $day ),
    proximate_days => $self->service_proximate_days( $service, $date, 6 ),
    service        => $spec[0],
    service_months => $self->service_months( $service, $year ),
    service_type   => $type,
    service_years  => $self->service_years($service),
    short_title    => $short_title,
    title          => $title,
    year           => $year,
  );
}

sub issue_proximate {
  my ( $self, $issue, $span ) = @_;

  my $before = $self->_cook_issues(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_issues',
        'WHERE issue <= ? AND _parent IS NULL',
        'ORDER BY issue DESC LIMIT ?' ),
      { Slice => {} },
      $issue,
      $span + 1
    )
  );

  my $after = $self->_cook_issues(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_issues',
        'WHERE issue > ? AND _parent IS NULL',
        'ORDER BY issue ASC LIMIT ?' ),
      { Slice => {} },
      $issue, $span
    )
  );

  push @$before, {} while @$before < $span + 1;
  push @$after,  {} while @$after < $span;
  return [reverse(@$before), @$after];
}

sub _issues_for_year {
  my ( $self, $year ) = @_;

  return $self->_cook_issues(
    $self->_child_fold(
      $self->dbh->selectall_arrayref(
        join( ' ',
          'SELECT ip.*, ic.region AS child_region, ic.pagecount AS child_pagecount ',
          'FROM genome_issues AS ip',
          'LEFT JOIN genome_issues AS ic',
          'ON ic._uuid=ip.default_child',
          'WHERE ip.`year`=?',
          'AND ip.`_parent` IS NULL',
          'ORDER BY `issue` ASC' ),
        { Slice => {} },
        $year
      )
    )
  );
}

sub _month_issues_for_year {
  my ( $self, $year ) = @_;
  my $issues = $self->group_by( $self->_issues_for_year($year), 'month' );
  return [map { ( $issues->{$_} || [] )->[0] } ( 1 .. 12 )];
}

sub issues_for_year {
  my ( $self, $year ) = @_;

  my $issues = $self->_issues_for_year($year);

  return (
    year => $year,
    issues   => $self->group_by( $issues, 'month' ),
    approved => $self->group_by( $issues, 'approved_year' ),
  );
}

sub lookup_uuid {
  my ( $self, $uuid ) = @_;
  my @row
   = $self->dbh->selectrow_hashref( 'SELECT * FROM dirty WHERE uuid=?',
    {}, $self->format_uuid($uuid) );
  return unless @row;
  return $row[0];
}

sub services_for_ids {
  my ( $self, @ids ) = @_;
  @ids = unique @ids;
  return [] unless @ids;
  return $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_services',
      'WHERE _uuid IN (',
      join( ', ', map '?', @ids ),
      ')' ),
    { Slice => {} },
    @ids
  );
}

sub service_info {
  my ( $self, @ids ) = @_;

  my $svcs = $self->services_for_ids(@ids);
  my @parent = grep defined $_, map { $_->{_parent} } @$svcs;
  if (@parent) {
    my $parents = $self->service_info(@parent);
    $_->{parent} = $parents->{ $_->{_parent} }[0]
     for grep { defined $_->{_parent} } @$svcs;
  }
  for my $svc (@$svcs) {
    $svc->{subkey} = $svc->{_key} unless defined $svc->{subkey};
    $svc->{full_title} = join ' ', $self->_walk_down( $svc, 'title' );
    $svc->{path}       = join '/', $self->_walk_down( $svc, 'subkey' );
  }
  return $self->group_by( $svcs, '_uuid' );
}

sub _walk_down {
  my ( $self, $service, $key ) = @_;
  return () unless $service->{$key};
  return ( $service->{$key} ) unless $service->{parent};
  return ( $self->_walk_down( $service->{parent}, $key ),
    $service->{$key} );
}

sub issue_listing {
  my ( $self, $uuid ) = @_;

  my $iss = $self->_cook_issues(
    [ $self->dbh->selectrow_hashref(
        join( ' ', 'SELECT *', 'FROM genome_issues', 'WHERE _uuid=?' ), {},
        $self->format_uuid($uuid)
      )
    ]
  )->[0];

  my $list = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_listings_v2',
      'WHERE `issue`=?',
      'AND `source`=?',
      'ORDER BY `page`, `date` ASC' ),
    { Slice => {} },
    $self->format_uuid($uuid),
    $self->source
  );

  my @services = unique map { $_->{service} } @$list;
  my $svc_info = $self->service_info(@services);

  my $svc_dates = $self->group_by(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT *',
        'FROM genome_service_dates',
        'WHERE `service` IN (',
        join( ', ', map '?', @services ),
        ')',
        'GROUP BY `service`',
        'ORDER BY `date` ASC' ),
      { Slice => {} },
      @services
    ),
    'service'
  );

  for my $i (@$list) {
    $i->{service_info}  = $svc_info->{ $i->{service} };
    $i->{service_dates} = $svc_dates->{ $i->{service} };
  }

  $iss->{listing} = $self->group_by( $list, 'date' );
  return (
    issue     => $iss,
    proximate => $self->issue_proximate( $iss->{issue}, 6 ),
    monthly   => $self->_month_issues_for_year( $iss->{year} ),
  );
}

sub stash {
  my ( $self, $name ) = @_;
  my @row
   = $self->dbh->selectrow_array(
    'SELECT stash FROM genome_stash WHERE name=?',
    {}, $name );
  return unless @row;
  return $self->_decode( $row[0] );
}

sub _programme_query {
  my ( $self, @args ) = @_;
  my $progs = $self->_add_programme_details(
    $self->dbh->selectall_arrayref(@args) );

  for my $prog (@$progs) {
    $prog->{outlet} = join '/',
     grep defined, @{$prog}{ 'root_service_key', 'subkey' };
  }

  return $progs;
}

sub _search_id {
  my ( $self, $uuid ) = @_;
  my @row
   = $self->dbh->selectrow_array(
    'SELECT id FROM genome_uuid_map WHERE uuid=?',
    {}, $uuid );
  return $row[0];
}

sub _search_load_services {
  my ( $self, $srch, @sids ) = @_;

  my $svcs
   = @sids
   ? $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *,',
      '  IF (`parent_service_key` IS NOT NULL, `parent_service_key`, `service_key`) AS `root_service_key`,',
      '  IF (`parent_service_name` IS NOT NULL, `parent_service_name`, `service_name`) AS `root_service_name`,',
      '  IF (`parent_service_order` IS NOT NULL, `parent_service_order`, `service_order`) AS `root_service_order`,',
      '  IF (`parent_service_type` IS NOT NULL, `parent_service_type`, `service_type`) AS `root_service_type`',
      'FROM (',
      '  SELECT',
      '    `s`.`_key` AS `service_key`,',
      '    `s`.`title` AS `service_name`,',
      '    `s`.`order` AS `service_order`,',
      '    `s`.`type` AS `service_type`,',
      '    `s2`.`_key` AS `parent_service_key`,',
      '    `s2`.`title` AS `parent_service_name`,',
      '    `s2`.`order` AS `parent_service_order`,',
      '    `s2`.`type` AS `parent_service_type`,',
      '    `m`.`id` AS `search_id`',
      '  FROM (`genome_services` AS `s`, `genome_uuid_map` AS `m`)',
      '  LEFT JOIN `genome_services` AS `s2` ON `s2`.`_uuid` = `s`.`_parent`',
      '  WHERE `m`.`uuid` = `s`.`_uuid`',
      '  AND `m`.`id` IN (',
      join( ', ', map '?', @sids ),
      '  )',
      ') AS `q`',
      'ORDER BY `root_service_type` DESC,',
      '  `root_service_order` IS NULL,',
      '  `root_service_order` ASC,',
      '  `root_service_name` ASC' ),
    { Slice => {} },
    @sids
   )
   : [];

  # Slightly icky - coallesce by rsk but retain general order
  my $by_rsk = $self->group_by( $svcs, 'root_service_key' );
  my @osvc = ();

  for my $svc (@$svcs) {
    my $rsk  = $svc->{root_service_key};
    my $list = delete $by_rsk->{$rsk};
    next unless $list;
    my @sid = sort { $a <=> $b } unique map { $_->{search_id} } @$list;
    push @osvc,
     {%$svc,
      link => $srch->service_link(@sid),
      svc  => join( ',', @sid ),
     };
  }
  return \@osvc;
}

sub search {
  my ( $self, @params ) = @_;

  my $srch = Lintilla::DB::Genome::Search->new(
    @params,
    index  => 'prog_idx',
    source => $self->_search_id( $self->source ),
  );

  my $results = $srch->search;

  my @ids = map { $_->{doc} } @{ $results->{matches} };
  my $ph = join ', ', map '?', @ids;

  my $o = $srch->order;
  my ( $ord, @extra )
   = $o eq 'rank' ? ( "ORDER BY FIELD(search_id, $ph) ", @ids )
   : $o eq 'asc'  ? ("ORDER BY `when` ASC")
   : $o eq 'desc' ? ("ORDER BY `when` DESC")
   :                die;

  my $progs
   = @ids
   ? $self->_programme_query(
    join( ' ',
      'SELECT *,',
      'IF (parent_service_key IS NOT NULL, parent_service_key, service_key) AS root_service_key',
      'FROM (',
      '  SELECT',
      '    p.*,',
      '    s2._key AS parent_service_key,',
      '    s.title AS service_name,',
      '    s2.title AS service_sub,',
      '    s.subkey AS subkey,',
      '    m.id AS search_id',
      '  FROM (genome_programmes_v2 AS p, genome_services AS s, genome_uuid_map AS m)',
      '  LEFT JOIN genome_services AS s2 ON s2._uuid = s._parent',
      '  WHERE p.service = s._uuid',
      '  AND p._uuid = m.uuid',
      "  AND m.id IN ($ph)",
      ") AS q $ord" ),
    { Slice => {} },
    @ids, @extra
   )
   : [];

  my $ssvc = $srch->services;
  my @sids = map { $_->{service_id} } @{ $ssvc->{matches} || [] };

  return (
    form       => $srch->form,
    results    => $results,
    programmes => $progs,
    services   => $self->_search_load_services( $srch, @sids ),
    pagination => $srch->pagination(5),
  );
}

sub programme {
  my ( $self, $uuid ) = @_;

  my $progs = $self->_programme_query(
    join( ' ',
      'SELECT *,',
      'IF (parent_service_key IS NOT NULL, parent_service_key, service_key) AS root_service_key,',
      'IF (parent_uuid IS NOT NULL, parent_uuid, service_uuid) AS root_uuid',
      'FROM (',
      '  SELECT',
      '    p.*,',
      '    s2._key AS parent_service_key,',
      '    s._uuid AS service_uuid,',
      '    s2._uuid AS parent_uuid,',
      '    s.title AS service_name,',
      '    s2.title AS service_sub,',
      '    s.subkey AS subkey',
      '  FROM (genome_programmes_v2 AS p, genome_services AS s)',
      '  LEFT JOIN genome_services AS s2 ON s2._uuid = s._parent',
      '  WHERE p.service = s._uuid',
      '  AND p._uuid = ?',
      ') AS q' ),
    { Slice => {} },
    $self->format_uuid($uuid)
  );

  my $rec    = $self->resolve_services( $progs->[0]{root_uuid} );
  my $issues = $self->issues( $progs->[0]{issue} );

  return (
    about     => $rec,
    spiel     => $self->_build_service_spiel($rec),
    programme => $progs->[0],
    issue     => $issues->[0],
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
