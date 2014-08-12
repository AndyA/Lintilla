package Lintilla::DB::Genome;

use Dancer ':syntax';
use JSON;
use Lintilla::Filter qw( cook );
use Moose;
use POSIX qw( strftime );
use Sphinx::Search;

=head1 NAME

Lintilla::DB::Genome - Genome model

=cut

use constant YEAR_START => 1923;
use constant YEAR_END   => 2009;

with 'Lintilla::Role::Gatherer';

has dbh => ( is => 'ro', isa => 'DBI::db' );

has source => (
  is      => 'ro',
  default => '70ba6e0c-c493-42bd-8c64-c9f4be994f6d',
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

sub _uniq(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

sub _format_uuid {
  my ( $self, $uuid ) = @_;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

sub _strip_uuid {
  my ( $self, $uuid ) = @_;
  # Format to validate
  ( my $stripped = $self->_format_uuid($uuid) ) =~ s/-//g;
  return $stripped;
}

sub _group_by {
  my ( $self, $rows, @keys ) = @_;
  my $leaf = pop @keys;
  my $hash = {};
  for my $row (@$rows) {
    my $rr   = {%$row};    # clone
    my $slot = $hash;
    $slot = ( $slot->{ delete $rr->{$_} } ||= {} ) for @keys;
    push @{ $slot->{ delete $rr->{$leaf} } }, $rr;
  }
  return $hash;
}

sub _build_services {
  my $self = shift;
  my $sql  = join ' ',
   'SELECT * FROM `genome_002`.`genome_services` ',
   'WHERE `_parent` IS NULL ',
   'ORDER BY `order` IS NULL, `order` ASC, `title` ASC';

  return $self->_group_by(
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

sub programme {
  my ( $self, $uuid ) = @_;
  return $self->dbh->selectrow_hashref(
    'SELECT * FROM `genome_programmes_v2` WHERE `_uuid`=?',
    {}, $self->_format_uuid($uuid) );
}

sub service_defaults {
  my ( $self, $service, @got ) = @_;
  my $sql = join ' ',
   'SELECT sd.date, s._uuid, s.has_outlets',
   'FROM genome_service_dates AS sd, genome_services AS s',
   'WHERE sd.service=s._uuid AND s._key=?',
   'ORDER BY date LIMIT 1';
  my $rec = $self->dbh->selectrow_hashref( $sql, {}, $service );
  die unless defined $rec;
  # Simple case
  return ( $rec->{date} ) unless $rec->{has_outlets} eq 'Y';

  if ( @got < 1 ) {
    # Find default outlet
    my $outlet = join ' ',
     'SELECT subkey FROM genome_services',
     'WHERE _parent=?',
     'ORDER BY `order` IS NULL, `order` ASC, `title` ASC';
    my $orec = $self->dbh->selectrow_hashref( $outlet, {}, $rec->{_uuid} );
    push @got, $orec->{subkey};
  }

  push @got, $rec->{date} if @got < 2;
  return @got;
}

sub resolve_service {
  my ( $self, $service, @spec ) = @_;
  my $rec = $self->dbh->selectrow_hashref(
    join( ' ',
      'SELECT _uuid, has_outlets, title, type',
      'FROM genome_services',
      'WHERE _key=?', 'LIMIT 1' ),
    {},
    $service
  );
  my ( $uuid, @title ) = @{$rec}{ '_uuid', 'title' };
  if ( $rec->{has_outlets} eq 'Y' ) {
    die unless @spec;
    my $outlet = $self->dbh->selectrow_hashref(
      'SELECT _uuid, title FROM genome_services WHERE _parent=? AND subkey=?',
      {}, $rec->{_uuid}, $spec[0]
    );
    die unless $outlet;
    $uuid = $outlet->{_uuid};
    push @title, $outlet->{title};
  }
  return ( $uuid, $rec->{type}, $rec->{title}, join ' ', @title );
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
  push @{ $by_parent{ $_->{_parent} }{ $_->{group} } }, $_ for @$contrib;
  for my $row (@$rows) {
    $row->{contrib} = $by_parent{ $row->{_uuid} } || [];
    $row->{time} = sprintf '%d.%02d', $self->decode_time( $row->{when} );
    $row->{link} = $self->clean_id( $row->{_uuid} );
  }
  return $rows;
}

sub _issue_pdf_path {
  my ( $self, $issue ) = @_;
  return join '/', $issue->{decade}, $issue->{year}, $issue->{_key},
   $issue->{_key} . '.pdf';
}

sub _issue_image_path {
  my ( $self, $issue ) = @_;
  return join '/', $issue->{decade}, $issue->{year}, $issue->{_key},
   $issue->{_key} . '-0.png';
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

sub _cook_issues {
  my ( $self, $issues ) = @_;

  return cook issues => [
    map {
      {
        %{ $self->_make_public($_) },
         path        => $self->_issue_image_path($_),
         pdf         => $self->_issue_pdf_path($_),
         month_name  => $MONTH[$_->{month} - 1],
         pretty_date => $self->_pretty_date( @{$_}{ 'year', 'month', 'day' } ),
         pretty_start_date =>
         $self->_pretty_date( $self->decode_date( $_->{start_date} ) ),
         pretty_end_date =>
         $self->_pretty_date( $self->decode_date( $_->{end_date} ) ),
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

sub _pretty_date {
  my ( $self, $y, $m, $d ) = @_;
  ( my $pd = strftime( "%d %B %Y", 0, 0, 0, $d, $m - 1, $y - 1900 ) )
   =~ s/^0//;
  return $pd;
}

sub listing_for_schedule {
  my ( $self, @spec ) = @_;

  my $date = pop @spec;
  my ( $year, $month, $day ) = $self->decode_date($date);
  my ( $service, $type, $short_title, $title )
   = $self->resolve_service(@spec);

  my $sql = join ' ',
   'SELECT * FROM genome_programmes_v2',
   'WHERE `source` = ?',
   'AND `service` = ?',
   'AND `year` = ?',
   'AND `month` = ?',
   'AND `day` = ?',
   'ORDER BY `when` ASC';

  my $rows = $self->dbh->selectall_arrayref( $sql, { Slice => {} },
    $self->source, $service, $year, $month, $day );

  my @pages  = _uniq map { $_->{page} } @$rows;
  my @issues = _uniq map { $_->{issue} } @$rows;

  return (
    outlet         => join( '/',                       @spec ),
    short_title    => $short_title,
    title          => $title,
    service_type   => $type,
    service_years  => $self->service_years($service),
    service_months => $self->service_months( $service, $year ),
    proximate_days => $self->service_proximate_days( $service, $date, 6 ),
    year           => $year,
    month          => $month,
    month_name     => $MONTH[$month - 1],
    day            => $day,
    service        => $spec[0],
    listing        => $self->_add_programme_details($rows),
    pages          => \@pages,
    pretty_date => $self->_pretty_date( $year, $month, $day ),
    issues      => $self->issues(@issues),
  );
}

sub issues_for_year {
  my ( $self, $year ) = @_;
  return (
    year   => $year,
    issues => $self->_group_by(
      $self->_cook_issues(
        $self->dbh->selectall_arrayref(
          join( ' ',
            'SELECT * ',
            'FROM genome_issues',
            'WHERE `year`=?',
            'AND `_parent` IS NOT NULL',
            'ORDER BY `issue` ASC' ),
          { Slice => {} },
          $year
        )
      ),
      'month'
    )
  );
}

sub lookup_uuid {
  my ( $self, $uuid ) = @_;
  my @row
   = $self->dbh->selectrow_hashref( 'SELECT * FROM dirty WHERE uuid=?',
    {}, $self->_format_uuid($uuid) );
  return unless @row;
  return $row[0];
}

sub services_for_ids {
  my ( $self, @ids ) = @_;
  @ids = _uniq @ids;
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
  return $self->_group_by( $svcs, '_uuid' );
}

sub _walk_down {
  my ( $self, $service, $key ) = @_;
  debug "service: ", $service, ", key: ", $key;
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
        $self->_format_uuid($uuid)
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
    $self->_format_uuid($uuid),
    $self->source
  );

  my @services = _uniq map { $_->{service} } @$list;
  my $svc_info = $self->service_info(@services);

  my $svc_dates = $self->_group_by(
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

  $iss->{listing} = $self->_group_by( $list, 'date' );
  return ( issue => $iss, );
}

sub stash {
  my ( $self, $name ) = @_;
  my @row
   = $self->dbh->selectrow_array(
    'SELECT stash FROM genome_stash WHERE name=?',
    {}, $name );
  return unless @row;
  return JSON->new->utf8->allow_nonref->decode( $row[0] );
}

=head2 Search

=cut

sub search {
  my ( $start, $size, $query ) = @_;
  #  $size = MAX_PAGE if $size > MAX_PAGE;

  my $sph = Sphinx::Search->new();
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetLimits( $start, $size );
  my $results = $sph->Query( $query, 'elvis_idx' );

  my $ids = join ', ', map { $_->{doc} } @{ $results->{matches} };
  my $sql
   = "SELECT * FROM elvis_image "
   . "WHERE acno IN ($ids) "
   . "ORDER BY FIELD(acno, $ids) ";

  database->selectall_arrayref( $sql, { Slice => {} } );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
