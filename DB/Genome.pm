package Lintilla::DB::Genome;

use v5.10;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use HTML::Tiny;
use Lintilla::DB::Genome::Blog;
use Lintilla::DB::Genome::Search::Sphinx;
use Lintilla::DB::Genome::Search::SphinxQL;
use Lintilla::DB::Genome::Search::Options;
use Lintilla::DB::Genome::Search::Pagination;
use Lintilla::Filter qw( cook );
use Moose;
use Text::Highlight;

=head1 NAME

Lintilla::DB::Genome - Genome model

=cut

our $VERSION = '0.1';

use constant YEAR_START       => 1923;
use constant YEAR_END         => 2009;
use constant INFAX_CONFIDENCE => 90;

with 'Lintilla::Role::DB';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Config';
with 'Lintilla::Role::DateTime';
with 'Lintilla::Role::Gatherer';
with 'Lintilla::Role::Source';
with 'Lintilla::Role::UUID';

has infax          => ( is => 'ro', isa => 'Bool', default => 0 );
has related        => ( is => 'ro', isa => 'Bool', default => 0 );
has related_merged => ( is => 'ro', isa => 'Bool', default => 0 );
has media          => ( is => 'ro', isa => 'Bool', default => 0 );
has blog_links     => ( is => 'ro', isa => 'Bool', default => 0 );
has blog_search    => ( is => 'ro', isa => 'Num',  default => 0 );

has years    => ( is => 'ro', lazy => 1, builder => '_build_years' );
has decades  => ( is => 'ro', lazy => 1, builder => '_build_decades' );
has services => ( is => 'ro', lazy => 1, builder => '_build_services' );
has blog     => ( is => 'ro', lazy => 1, builder => '_build_blog' );

# Slightly beastly gack
has _pseudo_map => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} },
);

sub unique(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

sub _build_services {
  my $self = shift;
  my $sql  = join ' ',
   'SELECT * FROM `genome_services` ',
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

sub _build_blog { Lintilla::DB::Genome::Blog->new( dbh => shift->dbh ) }

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

  return $self->decade_list( YEAR_START, YEAR_END, @$rs );
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

  my %bym = map {
    $_->{month} => { %$_, name => $self->month_names->[$_->{month} - 1] }
  } @$rs;

  return [map { $bym{$_} } ( 1 .. 12 )];
}

sub _pad_by_offset {
  my ( $self, $list ) = @_;

  return [] unless @$list;

  my %ent = map { $_->{offset} => $_ } @$list;
  my @ofs = sort { $a <=> $b } keys %ent;

  return [
    map {
      { %{ $ent{$_} || {} }, offset => $_ }
    } ( $ofs[0] .. $ofs[-1] )
  ];
}

sub _add_date {
  my ( $self, $list ) = @_;
  return [
    map {
      { %$_, $self->day_for_date( $_->{epoch} ) }
    } @$list
  ];
}

sub service_proximate_days {
  my ( $self, $service, $date, $span ) = @_;

  my @sql = (
    'SELECT `date`,',
    ' TO_DAYS(`date`) * 86400 - 62167219200 AS `epoch`, ',
    ' DATEDIFF(`date`, ?) AS `offset`',
    'FROM genome_service_dates',
    'WHERE service = ?',
  );

  my $rs = $self->_pad_by_offset(
    $self->_add_date(
      $self->dbh->selectall_arrayref(
        join( ' ',
          @sql,
          'AND `date` BETWEEN DATE_SUB(?, INTERVAL ? DAY) AND DATE_ADD(?, INTERVAL ? DAY)',
          'ORDER BY `date`' ),
        { Slice => {} },
        $date, $service, $date, $span, $date, $span
      )
    )
  );

  my $min_ofs = $rs->[0]{offset}  // 0;
  my $max_ofs = $rs->[-1]{offset} // 0;

  if ( $min_ofs > -$span ) {
    my $need = $span + $min_ofs;
    my $extra
     = $need > 1
     ? $self->_add_date(
      $self->dbh->selectall_arrayref(
        join( ' ', @sql, 'AND `date` < ? ORDER BY `date` DESC LIMIT ?' ),
        { Slice => {} },
        $date, $service, $rs->[0]{date}, $need - 1
      )
     )
     : [];

    if (@$extra) {
      unshift @$rs, reverse(@$extra), { gap => 1, offset => $min_ofs - 1 };
      $need -= 1 + @$extra;
    }

    unshift @$rs, { offset => ( $rs->[0]{offset} // 0 ) - 1 } for 1 .. $need;
  }

  if ( $max_ofs < $span ) {
    my $need = $span - $max_ofs;
    my $extra
     = $need > 1
     ? $self->_add_date(
      $self->dbh->selectall_arrayref(
        join( ' ', @sql, 'AND `date` > ? ORDER BY `date` LIMIT ?' ),
        { Slice => {} },
        $date, $service, $rs->[-1]{date}, $need - 1
      )
     )
     : [];

    if (@$extra) {
      push @$rs, { gap => 1, offset => $min_ofs - 1 }, @$extra;
      $need -= 1 + @$extra;
    }

    push @$rs, { offset => ( $rs->[-1]{offset} // 0 ) + 1 } for 1 .. $need;
  }

  return $rs;
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
  unless ( $rec->{has_outlets} eq 'Y' ) {
    return ( $got[0] ) if @got;
    return ( $rec->{date} );
  }

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

sub _find_service_near {
  my ( $self, $rel, $service, $date ) = @_;

  my ( $oper, $sort )
   = $rel eq 'before' ? ( '<',  'DESC' )
   : $rel eq 'after'  ? ( '>=', 'ASC' )
   :                    die;

  my $key = ( $service eq 'tv' || $service eq 'radio' ) ? 'type' : '_key';

  my $sql = join ' ',
   'SELECT sd.date, s._uuid, s.has_outlets, s.default_outlet, s._key',
   'FROM genome_service_dates AS sd, genome_services AS s',
   "WHERE sd.service=s._uuid AND s.$key=?",
   'AND s._parent IS NULL',
   "AND s.hidden = 'N'",
   "AND sd.date $oper ?",
   "ORDER BY date $sort, `order` IS NULL $sort, `order` $sort, `title` $sort LIMIT 1";

  my $rs = $self->dbh->selectrow_hashref( $sql, {}, $service, $date );
  return unless defined $rs;
  my $dt = $self->date2epoch($date) - $self->date2epoch( $rs->{date} );
  return { rec => $rs, delta => abs($dt) };
}

sub service_near {
  my ( $self, $service, $date ) = @_;

  my @best = (
    sort { $a->{delta} <=> $b->{delta} } (
      $self->_find_service_near( before => $service, $date ),
      $self->_find_service_near( after  => $service, $date )
    )
  );

  return ('missing') unless @best;
  my $rec = $best[0]{rec};

  return ( $rec->{_key}, $rec->{date} ) unless $rec->{has_outlets} eq 'Y';

  my ($subkey)
   = $self->dbh->selectrow_array(
    'SELECT subkey FROM genome_services WHERE _uuid=?',
    {}, $rec->{default_outlet} );

  return ( $rec->{_key}, $subkey, $rec->{date} );
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
    began       => $self->pretty_date( $rec->{began} ),
    ended       => $self->pretty_date( $rec->{ended} ),
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

sub clean_id {
  my ( $self, $uuid ) = @_;
  $uuid =~ s/-//g;
  return $uuid;
}

sub _add_default_programme_details {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;
  my $sql
   = 'SELECT * FROM genome_contributors WHERE _parent IN ('
   . join( ', ', map '?', @uids )
   . ') ORDER BY _parent, `index` ASC';
  my $contrib
   = @uids
   ? $self->dbh->selectall_arrayref( $sql, { Slice => {} }, @uids )
   : [];
  my %by_parent = ();
  for my $co (@$contrib) {
    $co->{type} //= 'Unknown';
    push @{ $by_parent{ $co->{_parent} } }, $co;
  }
  for my $row (@$rows) {
    $row->{contrib} = $by_parent{ $row->{_uuid} } || [];
    $row->{time} = sprintf '%d.%02d', $self->decode_time( $row->{when} );
    $row->{full_time} = sprintf '%02d:%02d:%02d',
     $self->decode_time( $row->{when} );
    $row->{link}        = $self->clean_id( $row->{_uuid} );
    $row->{pretty_date} = $self->pretty_date( $row->{date} );
    $row->{pretty_broadcast_date}
     = $self->pretty_date( $row->{broadcast_date} );
  }
  return $rows;
}

sub _add_infax_links {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;

  if (@uids) {
    my $irows = $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_infax WHERE uuid IN', '(',
        join( ', ', map '?', @uids ), ')' ),
      { Slice => {} },
      @uids
    );
    for my $irow (@$irows) {
      $irow->{pretty_date} = $self->pretty_date( $irow->{when} );
      $irow->{pretty_time} = sprintf '%02d:%02d',
       $self->decode_time( $irow->{when} );
      $irow->{pretty_score} = sprintf '%d',
       INFAX_CONFIDENCE * ( 1 - $irow->{score} );
    }
    my $infax = $self->group_by( $irows, 'uuid' );
    for my $row (@$rows) {
      my $ifx = delete $infax->{ $row->{_uuid} };
      $row->{infax} = $ifx->[0] if $ifx;
    }
  }

  return $rows;
}

sub _add_related_merged {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;

  if (@uids) {
    my $irows = $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_related_merged WHERE _parent IN', '(',
        join( ', ', map '?', @uids ), ')' ),
      { Slice => {} },
      @uids
    );

    my $related = $self->group_by( $irows, '_parent', 'location' );

    for my $row (@$rows) {
      my $rec = delete $related->{ $row->{_uuid} };
      $row->{related_merged} = $self->_make_public( $rec || [] );
    }
  }

  return $rows;
}

sub _add_related {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;

  if (@uids) {
    my $irows = $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT r.*, rm.`keep`',
        'FROM genome_related AS r',
        'LEFT JOIN genome_related_meta AS rm ON r._uuid=rm._uuid',
        'WHERE r._parent IN',
        '(',
        join( ', ', map '?', @uids ),
        ')',
        'ORDER BY r.`index`' ),
      { Slice => {} },
      @uids
    );

    my $related = $self->group_by( $irows, '_parent' );

    for my $row (@$rows) {
      my $rec = delete $related->{ $row->{_uuid} };
      $row->{related} = $self->_make_public( $rec || [] );
    }
  }

  return $rows;
}

sub _add_media {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;

  if (@uids) {
    my $irows = $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_media WHERE _parent IN',
        '(', join( ', ', map '?', @uids ),
        ')', 'ORDER BY `row_num`' ),
      { Slice => {} },
      @uids
    );

    my $media = $self->group_by( $irows, '_parent' );

    for my $row (@$rows) {
      my $rec = delete $media->{ $row->{_uuid} };
      for my $me (@$rec) {
        $me->{pretty_duration} = $self->pretty_duration( $me->{duration} );
      }
      $row->{media} = $self->_make_public( $rec || [] );
    }
  }

  return $rows;
}

sub _add_blog_links {
  my ( $self, $rows ) = @_;

  my $posts
   = $self->group_by(
    $self->blog->posts_for_programmes( map { $_->{_uuid} } @$rows ),
    "programme" );

  for my $row (@$rows) {
    $row->{blog} = delete $posts->{ $row->{_uuid} // [] };
  }

  return $rows;

}

sub media_count {
  my $self = shift;

  my ($count)
   = $self->dbh->selectrow_array("SELECT COUNT(*) FROM `genome_media`");
  return $count;
}

sub _add_programme_details {
  my ( $self, $rows ) = @_;
  $self->_add_default_programme_details($rows);

  $self->_add_infax_links($rows)    if $self->infax;
  $self->_add_related($rows)        if $self->related;
  $self->_add_related_merged($rows) if $self->related_merged;
  $self->_add_media($rows)          if $self->media;
  $self->_add_blog_links($rows)     if $self->blog_links;

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
  return join '/', $issue->{decade}, $issue->{year}, $key, $key . '-0.jpg';
}

sub _make_public {
  my ( $self, $in ) = @_;
  return [map { $self->_make_public($_) } @$in] if 'ARRAY' eq ref $in;
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
         month_name        => $self->month_names->[$_->{month} - 1],
         pretty_date       => $self->pretty_date( $_->{date} ),
         pretty_start_date => $self->pretty_date( $_->{start_date} ),
         pretty_end_date   => $self->pretty_date( $_->{end_date} ),
         short_date        => $self->short_date( $_->{date} ),
         short_start_date  => $self->short_date( $_->{start_date} ),
      }
    } @$issues
  ];
}

sub issues {
  my ( $self, @uuid ) = @_;

  return [] unless @uuid;

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
    title       => $self->page_title('Issues'),
    share_stash => $self->share_stash(
      title => 'List of Radio Times issues from 1923 to 2009 on BBC Genome'
    ),
    issues => $self->group_by(
      $self->_cook_issues(
        $self->dbh->selectall_arrayref(
          join( ' ',
            'SELECT *',
            'FROM genome_issues ',
            "WHERE approved_year='Y'",
            'AND _parent IS NULL',
            "AND hidden = 'N'",
            'ORDER BY `year`' ),
          { Slice => {} }
        )
      ),
      'decade'
    )
  );
}

sub _build_service_spiel {
  my ( $self, $rec ) = @_;
  my %case = ( tv => 'television', radio => 'radio', pseudo => 'radio' );
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
   'AND `broadcast_date` = ?',
   'ORDER BY `when` ASC';

  my $rows = $self->dbh->selectall_arrayref( $sql, { Slice => {} },
    $self->source, $service, $date );

  my $notes = $self->listing_notes($date);
  my $note = $self->find_note( $notes->{$date}, $service );

  my @pages  = unique map { $_->{page} } @$rows;
  my @issues = unique map { $_->{issue} } @$rows;

  my $pretty = $self->pretty_date( $year, $month, $day );

  return (
    about          => $rec,
    spiel          => $self->_build_service_spiel($rec),
    issues         => $self->issues(@issues),
    listing        => $self->_add_programme_details($rows),
    note           => $note,
    month_name     => $self->month_names->[$month - 1],
    outlet         => join( '/', @spec ),
    pages          => \@pages,
    pretty_date    => $pretty,
    proximate_days => $self->service_proximate_days( $service, $date, 6 ),
    service        => $spec[0],
    service_months => $self->service_months( $service, $year ),
    service_type   => $type,
    service_years  => $self->service_years($service),
    short_title    => $short_title,
    title          => $self->page_title( $title,       $pretty ),
    share_stash    => $self->share_stash(
      title => join( ' ', $title, $pretty, 'on BBC Genome' )
    ),
    year  => $year,
    month => $month,
    day   => $day,
    date  => $date,
  );
}

sub issue_proximate {
  my ( $self, $issue, $span ) = @_;

  my $before = $self->_cook_issues(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT * FROM genome_issues',
        'WHERE issue <= ?',
        'AND _parent IS NULL',
        "AND hidden = 'N'",
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
        'WHERE issue > ?',
        'AND _parent IS NULL',
        "AND hidden = 'N'",
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
          "AND ip.`hidden` = 'N'",
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
    title       => $self->page_title("Issues for $year"),
    share_stash => $self->share_stash(
      title => "Radio times issues for $year on BBC Genome"
    ),
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

sub _services_for_thing {
  my ( $self, $thing, @ids ) = @_;
  @ids = unique @ids;
  return [] unless @ids;
  return $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_services',
      "WHERE $thing IN (",
      join( ', ', map '?', @ids ),
      ')' ),
    { Slice => {} },
    @ids
  );
}

sub services_for_ids {
  my ( $self, @ids ) = @_;
  return [] unless @ids;
  my $svcs = $self->_services_for_thing( _uuid => @ids );

  $_->{data} = $self->_decode_wide( $_->{data} ) for @$svcs;

  my @inc = (
    map { @{ $_->{data}{incorporates} } }
     grep { 'HASH' eq ref $_->{data} && exists $_->{data}{incorporates} }
     @$svcs
  );

  my $inc
   = $self->stash_by( $self->_services_for_thing( _key => @inc ), '_key' );

  my @out = ();
  my $pm  = $self->_pseudo_map;

  for my $svc (@$svcs) {
    my $data = $svc->{data};
    if ( 'HASH' eq ref $data && exists $data->{incorporates} ) {
      my @sm = ();
      for my $i ( @{ $data->{incorporates} } ) {
        my $isvc = $inc->{$i} // die;
        push @out, @$isvc;
        push @sm, $_->{_uuid} for @$isvc;
      }
      $pm->{ $svc->{_uuid} } = [@sm];
    }
    else {
      push @out, $svc;
    }
  }

  return \@out;
}

sub service_info {
  my ( $self, @ids ) = @_;

  my $svcs = $self->services_for_ids(@ids);
  debug "svcs: ", $svcs;
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

sub _explode_listing {
  my ( $self, $list ) = @_;
  my $pm  = $self->_pseudo_map;
  my @out = ();
  for my $li (@$list) {
    if ( my $sm = $pm->{ $li->{service} } ) {
      for my $svc (@$sm) {
        push @out, { %$li, service => $svc };
      }
    }
    else {
      push @out, $li;
    }
  }
  return \@out;
}

sub listing_notes {
  my ( $self, @dates ) = @_;

  return {} unless @dates;

  my $notes = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT ln.`date`, ln.`service`, cm.`message`',
      'FROM genome_listing_notes AS ln, genome_content_messages AS cm',
      'WHERE ln.message_id=cm.id',
      'AND `date` IN (',
      join( ', ', map '?', @dates ),
      ')',
      'ORDER BY service IS NULL, service' ),
    { Slice => {} },
    @dates
  );

  return $self->group_by( $notes, 'date' );
}

sub find_note {
  my ( $self, $notes, @svcs ) = @_;
  return unless $notes;
  my %got = map { $_ => 1 } @svcs;
  for my $note (@$notes) {
    return $note if defined $note->{service} && $got{ $note->{service} };
    return $note if !defined $note->{service};
  }
  return;
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
  @services = keys %$svc_info;

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

  $list = $self->_explode_listing($list);

  for my $i (@$list) {
    $i->{service_info}  = $svc_info->{ $i->{service} };
    $i->{service_dates} = $svc_dates->{ $i->{service} };
  }

  my $by_date       = $self->group_by( $list, 'date' );
  my $notes         = $self->listing_notes( keys %$by_date );
  my $notes_by_date = {};

  while ( my ( $date, $items ) = each %$by_date ) {
    my @svc = unique map { $_->{service} } @$items;
    my $note = $self->find_note( $notes->{$date}, @svc );
    $notes_by_date->{$date} = $note if defined $note;
  }

  $iss->{listing} = $by_date;
  $iss->{notes}   = $notes_by_date;

  my @rv = (
    title =>
     $self->page_title( "Issue " . $iss->{issue}, $iss->{pretty_date} ),
    share_stash => $self->share_stash(
      title => join( ' ',
        'Radio Times issue',
        join( ', ', $iss->{issue}, $iss->{pretty_date} ),
        'on BBC Genome' )
    ),
    issue     => $iss,
    proximate => $self->issue_proximate( $iss->{issue}, 6 ),
    monthly   => $self->_month_issues_for_year( $iss->{year} ),
  );
  return @rv;
}

sub stash {
  my ( $self, $name ) = @_;
  my @row
   = $self->dbh->selectrow_array(
    'SELECT stash FROM genome_stash WHERE name=?',
    {}, $name );
  return unless @row;
  return $self->_decode_wide( $row[0] );
}

sub _programme_query {
  my ( $self, @args ) = @_;
  my $progs = $self->_add_programme_details(
    $self->dbh->selectall_arrayref(@args) );

  for my $prog (@$progs) {
    $prog->{outlet} = join '/',
     grep defined, @{$prog}{ 'root_service_key', 'subkey' };
    $prog->{service_full} = join ' ',
     grep defined, @{$prog}{ 'service_sub', 'service_name' };
    $prog->{dayname} = $self->day_name( $prog->{weekday} )
     if defined $prog->{weekday};
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

  # Convert incorporated services into the real services they
  # incoporate
  @sids = $self->_services_incorporated_to_real(@sids);

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

sub unstem {
  my ( $self, $dflt, @words ) = @_;
  return () unless @words;
  my $rs = $self->dbh->selectall_hashref(
    join( ' ',
      'SELECT *',
      'FROM genome_unstem',
      'WHERE stem IN (',
      join( ', ', map "?", @words ), ')' ),
    'stem',
    {},
    @words
  );

  my @out = ();
  for my $word (@words) {
    push @out, split /,/, $rs->{$word}{words} if $rs->{$word};
    push @out, $dflt->{$word} if defined $dflt->{$word};
    push @out, $word;
  }
  return @out;
}

sub _highlight_progs {
  my ( $self, $progs, $words ) = @_;

  # TODO related_merged
  my $hl = Text::Highlight->new( words => $words // [] );
  for my $prog (@$progs) {
    for my $key ( 'title', 'synopsis' ) {
      $prog->{"${key}_html"} = $hl->highlight( $prog->{$key} )
       if exists $prog->{$key};
    }
  }
}

sub _search_all {
  my ( $self, $options ) = @_;

  return ( 0, [] ) unless $options->is_valid;

  my @bind  = ();
  my @filt  = ();
  my $table = "genome_search";

  if ( $options->adv ) {
    push @filt, "`s`.`when` >= ? AND `s`.`when` < ?";
    push @bind, sprintf( '%04d-01-01', $options->yf ),
     sprintf( '%04d-01-01', $options->yt + 1 );

    my @df = $options->day_filter;
    if (@df) {
      push @filt, "`s`.`weekday` IN (" . join( ", ", map "?", @df ) . ")";
      push @bind, @df;
    }

    {
      my ( $from, $to, $invert ) = $options->month_filter;
      if ( defined $from ) {
        push @filt, join " ", "`s`.`month`", ( $invert ? ("NOT") : () ),
         "BETWEEN ? AND ?";
        push @bind, $from, $to;
      }
    }

    {
      my ( $from, $to, $invert ) = $options->time_filter;
      if ( defined $from ) {
        push @filt, join " ", "`s`.`timeslot`", ( $invert ? ("NOT") : () ),
         "BETWEEN ? AND ?";
        push @bind, $from, $to;
      }
    }

    {
      my $media = $options->media;
      if ( $media eq "tv" || $media eq "radio" ) {
        push @filt, "`s`.`service_type` = ?";
        push @bind, $media eq "tv"
         ? $options->SERVICE_TV
         : $options->SERVICE_RADIO;
      }
      elsif ( $media eq "playable" ) {
        $table = "genome_search_has_media";
      }
      elsif ( $media eq "related" ) {
        $table = "genome_search_has_related";
      }
    }
  }

  # Enumerate available services
  my @services = @{
    $self->dbh->selectcol_arrayref(
      join( " ",
        "SELECT DISTINCT `s`.`service_id` FROM `$table` AS `s`",
        @filt ? ( "WHERE", join " AND ", @filt ) : () ),
      {},
      @bind
    ) // [] };

  # Limit to selected service(s)
  if ( defined( my $svc = $options->svc ) ) {
    my @svc = split /,/, $svc;
    if (@svc) {
      push @filt, "`s`.`service_id` IN(" . join( ", ", map "?", @svc ) . ")";
      push @bind, @svc;
    }
  }

  my ($count) = $self->dbh->selectrow_array(
    join( " ",
      "SELECT COUNT(*) AS `count` FROM `$table` AS `s`",
      @filt ? ( "WHERE", join " AND ", @filt ) : () ),
    {},
    @bind
  );

  my $dir = $options->order eq "desc" ? "DESC" : "ASC";

  my @ids = @{
    $self->dbh->selectcol_arrayref(
      join( " ",
        "SELECT `s`.`_uuid` FROM `$table` AS `s`",
        @filt ? ( "WHERE", join " AND ", @filt ) : (),
        "ORDER BY `when` $dir",
        "LIMIT ?, ?" ),
      {},
      @bind,
      $options->start,
      $options->size
    ) // [] };

  my $progs
   = @ids
   ? $self->_programme_query(
    join( ' ',
      'SELECT *,',
      'IF (parent_service_key IS NOT NULL, parent_service_key, service_key) AS root_service_key',
      'FROM (',
      '  SELECT',
      '    p.*,',
      '    dayofweek(`p`.`date`) AS `weekday`,',
      '    s2._key AS parent_service_key,',
      '    s.title AS service_name,',
      '    s2.title AS service_sub,',
      '    s.subkey AS subkey',
      '  FROM (genome_programmes_v2 AS p, genome_services AS s)',
      '  LEFT JOIN genome_services AS s2 ON s2._uuid = s._parent',
      '  WHERE p.service = s._uuid',
      '  AND p._uuid IN (',
      join( ", ", map "?", @ids ),
      '  )',
      ') AS q',
      'ORDER BY FIELD(`_uuid`, ',
      join( ", ", map "?", @ids ),
      ')' ),
    { Slice => {} },
    @ids, @ids
   )
   : [];

  return ( $count, $progs, @services );

}

sub _no_query_search {
  my ( $self, $options ) = @_;

  my ( $count, $progs, @services ) = $self->_search_all($options);

  $self->_highlight_progs($progs);

  my $self_link  = $options->self_link;
  my $pagination = Lintilla::DB::Genome::Search::Pagination->new(
    options => $options,
    total   => $count,
    window  => 10
  );

  return (
    form        => $options->form,
    results     => { total_found => $count },
    programmes  => $progs,
    services    => $self->_search_load_services( $options, @services ),
    pagination  => $pagination->pagination,
    title       => $self->page_title('Search Results'),
    share_stash => $self->share_stash(
      title => join( ' ', 'Search BBC Genome' ),
      ( defined $self_link ? ( shareUrl => $self_link ) : () ),
    ),
  );
}

sub _query_search {
  my ( $self, $options ) = @_;

  my $srch = Lintilla::DB::Genome::Search::Sphinx->new(
    options => $options,
    index   => 'genome3_idx',
    source  => $self->_search_id( $self->source ),
  );

  my $results = $srch->search;

  my @ids = map { $_->{doc} } @{ $results->{matches} };
  my $ph = join ', ', map '?', @ids;

  my $o = $options->order;
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
      '    dayofweek(`p`.`date`) AS `weekday`,',
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
  my $kwm  = $srch->keyword_map;
  my @kw   = $self->unstem( $kwm, keys %{ $results->{words} } );

  $self->_highlight_progs( $progs, \@kw );

  my @sids = map { $_->{service_id} } @{ $ssvc->{matches} || [] };

  my $self_link  = $options->self_link;
  my $pagination = Lintilla::DB::Genome::Search::Pagination->new(
    options => $options,
    total   => $srch->total,
    window  => 10
  );

  my %rv = (
    form        => $options->form,
    results     => $results,
    programmes  => $progs,
    services    => $self->_search_load_services( $options, @sids ),
    pagination  => $pagination->pagination,
    title       => $self->page_title('Search Results'),
    share_stash => $self->share_stash(
      title => join( ' ', 'Search for', $options->q, 'on BBC Genome' ),
      ( defined $self_link ? ( shareUrl => $self_link ) : () ),
    ),
  );

  $rv{blog_hits} = $self->_blog_search($options)
   if $self->blog_search && $options->page == 0;

  return %rv;
}

sub _blog_search {
  my ( $self, $options ) = @_;
  my $blog  = $self->blog;
  my $posts = $blog->search( $options->q, 0, $self->blog_search );
  my @ids   = map { $_->{doc} } @{ $posts->{qq}{matches} };
  return $blog->posts_by_id(@ids);
}

sub _services_real_to_incorporated {
  my ( $self, @ids ) = @_;

  return unless @ids;

  return @{
    $self->dbh->selectcol_arrayref(
      join( " ",
        "SELECT DISTINCT u1.id",
        "  FROM genome_uuid_map AS u1,",
        "       genome_uuid_map AS u2,",
        "       genome_service_incorporates AS si",
        " WHERE u1.uuid=si.incorporated_into",
        "   AND u2.uuid=si.service",
        "   AND u2.id IN (",
        join( ", ", map "?", @ids ),
        ")" ),
      {},
      @ids
    ) };
}

sub _services_incorporated_to_real {
  my ( $self, @ids ) = @_;

  return unless @ids;

  return @{
    $self->dbh->selectcol_arrayref(
      join( " ",
        "SELECT DISTINCT u1.id",
        "  FROM genome_uuid_map AS u1,",
        "       genome_uuid_map AS u2,",
        "       genome_service_incorporates AS si",
        " WHERE u1.uuid=si.service",
        "   AND u2.uuid=si.incorporated_into",
        "   AND u2.id IN (",
        join( ", ", map "?", @ids ),
        ")" ),
      {},
      @ids
    ) };
}

sub search {
  my ( $self, %params ) = @_;

  # Expand real services to include combined services that include them
  if ( defined $params{svc} ) {
    $params{svc} = join ",",
     $self->_services_real_to_incorporated( split /,/, $params{svc} );
  }

  my $options = Lintilla::DB::Genome::Search::Options->new(%params);

  # my $spql = Lintilla::DB::Genome::Search::SphinxQL->new(
  #   sph     => database("sphinx"),
  #   index   => "genome3_idx",
  #   options => $options
  # );

  my %rv
   = length( $options->q )
   ? $self->_query_search($options)
   : $self->_no_query_search($options);

  # $rv{sphinxql} = $spql->_do_search($options);

  return %rv;
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

  my @desc = @{ $progs->[0] }{ 'title', 'service_full', 'pretty_date' };

  return (
    about     => $rec,
    spiel     => $self->_build_service_spiel($rec),
    programme => $progs->[0],
    issue     => $issues->[0],
    share_stash =>
     $self->share_stash( title => join( ', ', @desc ) . ' on BBC Genome' ),
    title => $self->page_title(@desc),
  );
}

sub site_name { 'BBC Genome' }

sub page_title {
  my ( $self, @title ) = @_;
  return join ' - ', @title, $self->site_name;
}

sub share_stash {
  my ( $self, %vals ) = @_;
  my %default = (
    locale       => 'en.gb',
    title        => 'BBC Genome',
    description  => 'Radio Times 1923-2009',
    variant      => 'default',
    variantPanel => 'light',
    twitterName  => 'bbcgenome',
  );

  return { %default, %vals };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
