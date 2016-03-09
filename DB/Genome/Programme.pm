package Lintilla::DB::Genome::Programme;

use v5.10;

use Moose;
use Dancer qw( :syntax );

with 'Lintilla::Role::DB';
with 'Lintilla::Role::Source';
with 'Lintilla::Role::UUID';

use constant BROADCAST_OFFSET => 5;

sub _parse_contributor_line {
  my ( $self, $ln ) = @_;
  return ( $1, $2 ) if $ln =~ m{^\s*([^:]+):\s*(.+?)\s*$};
  return ( $1, $2 ) if $ln =~ m{^\s*(\S+)\s*(.+)$};    # handle Title Name
  return ( 'Unknown', $ln );
}

sub parse_contributors {
  my ( $self, $contrib ) = @_;
  return $contrib if ref $contrib;
  my $idx = 0;
  my @row = ();
  for my $ln ( split /\n/, $contrib ) {
    next if $ln =~ m{^\s*$};
    my ( $type, $name ) = $self->_parse_contributor_line($ln);
    $type = undef if $type eq 'Unknown';
    my @np    = split /\s+/, $name;
    my $last  = pop @np;
    my $first = @np ? join( ' ', @np ) : undef;
    push @row,
     {type       => $type,
      first_name => $first,
      last_name  => $last
     };
  }
  return \@row;
}

sub _default_contrib {
  my ( $self, $data ) = @_;
  my $idx = 0;
  for my $row (@$data) {
    %$row = (
      index => $idx,
      group => 'crew',
      kind  => 'member',
      code  => undef,
      %$row
    );
    $idx = $row->{index} + 1;
  }
  return $data;
}

sub _store_contrib {
  my ( $self, $uuid, $contrib ) = @_;
  $self->transaction(
    sub {
      my $data
       = $self->_default_contrib( $self->parse_contributors($contrib) );
      my $fuuid = $self->format_uuid($uuid);
      $self->dbh->do( 'DELETE FROM genome_contributors WHERE _parent=?',
        {}, $fuuid );
      if (@$data) {
        my %kk = ();
        %kk = ( %kk, %$_ ) for @$data;
        delete $kk{_parent};    # override
        my @f = sort keys %kk;
        my $val = join ', ', ('?') x @f;
        $self->dbh->do(
          join( ' ',
            'INSERT INTO genome_contributors',
            '(',
            join( ', ', map { "`$_`" } '_parent', @f ),
            ') VALUES',
            join( ', ', map { "( ?, $val )" } @$data ) ),
          {},
          map { $fuuid, @{$_}{@f} } @$data
        );
      }
    }
  );
}

sub _fetch_contrib {
  my ( $self, $uuid ) = @_;
  return $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_contributors',
      'WHERE _parent=?',
      'ORDER BY `index`' ),
    { Slice => {} },
    $self->format_uuid($uuid)
  );
}

sub _listing_for_service_date {
  my ( $self, $service, $date ) = @_;

  my ($listing) = $self->dbh->selectrow_array(
    join( " ",
      "SELECT `_uuid`",
      "  FROM `genome_listings_v2`",
      " WHERE `date` = DATE(DATE_SUB(?, INTERVAL ? HOUR))",
      "   AND `service` = ?" ),
    {},
    $date,
    BROADCAST_OFFSET,
    $service
  );

  die "Can't find listing for $date"
   unless defined $listing;

  return $listing;
}

sub _update {
  my ( $self, $uuid, $data ) = @_;

  $self->transaction(
    sub {
      $self->_store_contrib( $uuid, delete $data->{contributors} )
       if exists $data->{contributors};

      my @xb = ();
      my @xf = ();

      # If 'when' is in the field list we need to find the correct listing
      # and update the day, month, year, date and broadcast_date fields.
      if ( defined $data->{when} ) {
        push @xf,
         ('`day` = DAY(?)',
          '`month` = MONTH(?)',
          '`year` = YEAR(?)',
          '`date` = DATE(?)',
          '`broadcast_date` = DATE(DATE_SUB(?, INTERVAL ? HOUR))'
         );

        push @xb, ( ( $data->{when} ) x 5, BROADCAST_OFFSET );

        # Get the programme service
        my ($service)
         = $self->dbh->selectrow_array(
          "SELECT `service` FROM `genome_programmes_v2` WHERE `_uuid` = ?",
          {}, $uuid );

        die "Can't find programme $uuid"
         unless defined $service;

        $data->{listing}
         = $self->_listing_for_service_date( $service, $data->{when} );
      }

      my @f = sort keys %$data;

      my @b = @{$data}{@f};

      $self->dbh->do(
        join( ' ',
          'UPDATE', "`genome_programmes_v2`", 'SET',
          join( ', ', '`_modified`=NOW()', @xf, map { "`$_`=?" } @f ),
          'WHERE _uuid=? LIMIT 1' ),
        {},
        @xb, @b, $uuid
      );
    }
  );

  return $uuid;
}

=for ref

programme
  +----------------+------------------+------+-----+---------+-------+
  | Field          | Type             | Null | Key | Default | Extra |
  +----------------+------------------+------+-----+---------+-------+
  | _uuid          | varchar(36)      | NO   | PRI | NULL    |       |
  | _created       | datetime         | NO   |     | NULL    |       |
  | _modified      | datetime         | NO   |     | NULL    |       |
  | _key           | varchar(48)      | NO   | MUL | NULL    |       |
  | _parent        | varchar(36)      | YES  | MUL | NULL    |       |
  | _edit_id       | int(10)          | YES  |     | NULL    |       |
  | source         | varchar(36)      | NO   | MUL | NULL    |       |
  | service        | varchar(36)      | YES  | MUL | NULL    |       |
  | service_key    | varchar(48)      | YES  | MUL | NULL    |       |
  | issue          | varchar(36)      | NO   | MUL | NULL    |       |
  | issue_key      | varchar(48)      | NO   | MUL | NULL    |       |
  | listing        | varchar(36)      | YES  | MUL | NULL    |       |
  | title          | varchar(256)     | NO   |     | NULL    |       |
  | episode_title  | varchar(256)     | YES  |     | NULL    |       |
  | episode        | int(11)          | YES  |     | NULL    |       |
  | synopsis       | text             | YES  |     | NULL    |       |
  | footnote       | text             | YES  |     | NULL    |       |
  | text           | text             | YES  |     | NULL    |       |
  | when           | datetime         | NO   |     | NULL    |       |
  | duration       | int(10) unsigned | NO   |     | NULL    |       |
  | type           | varchar(48)      | YES  | MUL | NULL    |       |
  | year           | int(11)          | NO   | MUL | NULL    |       |
  | month          | int(11)          | NO   | MUL | NULL    |       |
  | day            | int(11)          | NO   | MUL | NULL    |       |
  | date           | date             | YES  | MUL | NULL    |       |
  | broadcast_date | date             | YES  | MUL | NULL    |       |
  | page           | int(11)          | YES  |     | NULL    |       |
  +----------------+------------------+------+-----+---------+-------+

_uuid
  +---------------------------------+---------+
  | found_in                        | count   |
  +---------------------------------+---------+
  | dirty.uuid                      | 9328705 |
  | genome_changelog.uuid           |   70795 |
  | genome_contributors._parent     | 4360500 |
  | genome_coordinates._parent      | 9328685 |
  | genome_edit.uuid                |   75848 |
  | genome_edit_digest.uuid         |   75848 |
  | genome_infax.uuid               | 4119064 |
  | genome_media._parent            |    3877 |
  | genome_overrides._uuid          |       1 |
  | genome_programmes_v2._parent    |   62700 |
  | genome_programmes_v2._uuid      | 9328705 |
  | genome_related._parent          |  402335 |
  | genome_tables._parent           |  401255 |
  | genome_uuid_map.uuid            | 9328705 |
  | labs_contributor_programme.uuid | 4356969 |
  +---------------------------------+---------+

listing
  +------------------------------+--------+
  | found_in                     | count  |
  +------------------------------+--------+
  | dirty.uuid                   | 471589 |
  | genome_listings_v2._uuid     | 471589 |
  | genome_programmes_v2.listing | 471589 |
  | genome_related._parent       | 127950 |
  +------------------------------+--------+

issue
  +-----------------------------+-------+
  | found_in                    | count |
  +-----------------------------+-------+
  | dirty.uuid                  |  4450 |
  | genome_coordinates.issue    |  4450 |
  | genome_issues.default_child |  3664 |
  | genome_issues._uuid         |  4450 |
  | genome_listings_v2.issue    |  4450 |
  | genome_programmes_v2.issue  |  4450 |
  | genome_related.issue        |  4450 |
  | genome_tables.issue         |  3235 |
  +-----------------------------+-------+

service
  +--------------------------------+-------+
  | found_in                       | count |
  +--------------------------------+-------+
  | dirty.uuid                     |    71 |
  | genome_listings_v2.service     |    71 |
  | genome_listing_notes.service   |     1 |
  | genome_programmes_v2.service   |    71 |
  | genome_services.default_outlet |     8 |
  | genome_services.preceded_by    |     4 |
  | genome_services.succeeded_by   |     2 |
  | genome_services._uuid          |    71 |
  | genome_service_aliases._parent |    53 |
  | genome_service_dates.service   |    67 |
  | genome_uuid_map.uuid           |    71 |
  | labs_service_dates.service     |    68 |
  +--------------------------------+-------+

Minimum fields required for a programme

  when
  title
  synopsis
  service / listing
  issue

=cut

sub _create {
  my ( $self, $uuid, $data ) = @_;

  my @missing = grep { !exists $data->{$_} } qw(
   when title synopsis service issue duration
  );

  die "Missing fields in programme: ", join( ", ", @missing )
   if @missing;

  $data = {
    _uuid => $uuid,
    %$data,
    _key   => $uuid,           # Not like the original but unused
    type   => "normal",
    source => $self->source,
  };

  $data->{listing} //=
   $self->_listing_for_service_date( $data->{service}, $data->{when} );

  my @f = sort keys %$data;
  my @b = @{$data}{@f};
  my @v = ("?") x @b;

  my %xf = (
    _created  => ["NOW()"],
    _modified => ["NOW()"],
    year      => ["YEAR(?)", $data->{when}],
    month     => ["MONTH(?)", $data->{when}],
    day       => ["DAY(?)", $data->{when}],
    date      => ["DATE(?)", $data->{when}],
    broadcast_date =>
     ["DATE(DATE_SUB(?, INTERVAL ? HOUR))", $data->{when}, BROADCAST_OFFSET]
  );

  while ( my ( $field, $expr ) = each %xf ) {
    next if exists $data->{$field};
    push @f, $field;
    push @v, shift @$expr;
    push @b, @$expr;
  }

  $self->dbh->do(
    join( " ",
      "INSERT INTO `genome_programmes_v2` (",
      join( ", ", map { "`$_`" } @f ),
      ") VALUES (", join( ", ", @v ), ")" ),
    {},
    @b
  );

  return $uuid;
}

sub store {
  my ( $self, $uuid, $data, $edit_id ) = @_;

  my $rec = {%$data};

  $rec->{_edit_id} = $edit_id
   if defined $edit_id;

  # Update existing
  return $self->_update( $uuid, $data )
   if defined $uuid;

  # Create new
  return $self->_create( $self->make_uuid, $data );
}

sub fetch {
  my ( $self, $uuid ) = @_;
  my $fuuid = $self->format_uuid($uuid);
  my $prog  = $self->dbh->selectrow_hashref(
    'SELECT `_modified`, `_edit_id`, `title`, `synopsis`, `when` FROM `genome_programmes_v2` WHERE `_uuid`=?',
    {}, $fuuid
  );
  $prog->{contributors} = $self->_fetch_contrib($fuuid);
  return $prog;
}

1;
