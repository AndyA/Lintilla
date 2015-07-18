package Lintilla::DB::Genome::Search::SphinxQL;

=head1 NAME

Lintilla::DB::Genome::Search::SphinxQL - A SphinxQL search

=cut

use v5.10;
use Moose;

with 'Lintilla::Role::SphinxQL';

our $VERSION = '0.1';

has index => (
  is       => 'ro',
  isa      => 'Str',
  required => 1
);

has options => (
  is       => 'ro',
  isa      => 'Lintilla::DB::Genome::Search::Options',
  required => 1
);

has max_matches => (
  is      => 'ro',
  isa     => 'Num',
  default => 20_000
);

sub _do_search {
  my $self    = shift;
  my $options = $self->options;

  my @filt = ();
  my @bind = ();

  my $set_range = sub {
    my ( $field, $from, $to, $invert ) = @_;
    if ( defined $from ) {
      push @filt, join " ", "`$field`", ( $invert ? ("NOT") : () ),
       "BETWEEN $from AND $to";
    }
  };

  my $set_set = sub {
    my ( $field, @range ) = @_;
    return unless @range;
    push @filt, "`$field` IN (" . join( ", ", @range ) . ")";
  };

  # SphinxQL doesn't support NOT BETWEEN x AND y so we represent
  # inverted month ranges as a set
  my $set_month = sub {
    my ( $field, $from, $to, $invert ) = @_;
    return $set_range->( $field, $from, $to, 0 ) unless $invert;
    my %months = map { $_ => 1 } 1 .. 12;
    delete @months{ $from .. $to };
    $set_set->( $field, keys %months );
  };

  # And timeslot ranges using timeslot_tomorrow which is
  # timeslot + 24hrs
  my $set_timeslot = sub {
    my ( $field, $from, $to, $invert ) = @_;
    return $set_range->( $field, $from, $to, 0 ) unless $invert;
    push @filt, "`$field` > $to",
     "`${field}_tomorrow` < " . ( $from + 86400 );
  };

  if ( defined $options->q && length $options->q ) {
    push @filt, "MATCH(?)";
    push @bind,
     ( $options->adv && $options->co )
     ? '@people "' . $options->q . '"'
     : $options->q;
  }

  if ( $options->adv ) {
    $set_range->( "year", $options->yf, $options->yt, 0 );
    $set_set->( "weekday", $options->day_filter );
    $set_month->( "month", $options->month_filter );
    $set_timeslot->( "timeslot", $options->time_filter );

    my $media = $options->media;
    if ( $media eq "tv" || $media eq "radio" ) {
      push @filt,
       "`service_type` = "
       . (
          $media eq "tv"
        ? $options->SERVICE_TV
        : $options->SERVICE_RADIO
       );
    }
    elsif ( $media eq "playable" ) {
      push @filt, "`has_media` <> 0";
    }
    elsif ( $media eq "related" ) {
      push @filt, "`has_related` <> 0";
    }
  }

  my $index = $self->index;

  # Enumerate available services
  my @services = @{
    $self->sph->selectcol_arrayref(
      join( " ",
        "SELECT `service_id` FROM `$index`",
        ( @filt ? ( "WHERE", join " AND ", @filt ) : () ),
        "GROUP BY `service_id`",
        "LIMIT ? OPTION max_matches=?" ),
      { Columns => [1] },
      @bind, 1000, 1000
    ) // [] };

  # Limit to selected service(s)
  if ( defined( my $svc = $options->svc ) ) {
    $set_set->( "service_id", split /,/, $svc );
  }

  my @ids = $self->sph->selectcol_arrayref(
    join( " ",
      "SELECT `id` FROM `$index`",
      ( @filt ? ( "WHERE", join " AND ", @filt ) : () ),
      "LIMIT ?, ? OPTION max_matches=?" ),
    { Columns => [1] },
    @bind,
    $options->start,
    $options->size,
    $self->max_matches
  );

  return {
    services => \@services,
    hits     => \@ids,
    meta     => $self->get_meta
  };

}

1;
