package Lintilla::DB::Genome::Programme;

use v5.10;

use Moose;
use Dancer qw( :syntax );

with 'Lintilla::Role::DB';
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

sub store {
  my ( $self, $uuid, $data, $edit_id ) = @_;

  my $rec = {%$data};

  $rec->{_edit_id} = $edit_id
   if defined $edit_id;

  # Update existing
  return $self->_update( $uuid, $data )
   if defined $uuid;

  die "Can't create a new programme";
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
