package Lintilla::Role::DateTime;

use Moose::Role;

use POSIX qw( strftime );
use Time::Local;

=head1 NAME

Lintilla::Role::DateTime - Date / time handling

=cut

requires 'config';

use constant YEAR_START => 1923;
use constant YEAR_END   => 2009;

my @DAY_FULL = qw(
 Sunday Monday Tuesday Wednesday Thursday Friday Saturday
);

my @DAY = qw(
 Sun Mon Tue Wed Thu Fri Sat
);

my @MONTH = qw(
 January   February March    April
 May       June     July     August
 September October  November December
);

sub short_date {
  my ( $self, $y, $m, $d ) = @_;
  return undef unless defined $y;
  ( $y, $m, $d ) = $self->decode_date($y) unless defined $m;
  return sprintf '%02d %s', $d, substr $MONTH[$m - 1], 0, 3;
}

sub pretty_date {
  my ( $self, $y, $m, $d ) = @_;
  return undef unless defined $y;
  ( $y, $m, $d ) = $self->decode_date($y) unless defined $m;
  ( my $pd = strftime( "%d %B %Y", 0, 0, 0, $d, $m - 1, $y - 1900 ) )
   =~ s/^0//;
  return $pd;
}

sub pretty_duration {
  my ( $self, $secs ) = @_;

  my @uname = ( 'hour', 'minute', 'second' );
  my @part  = ();
  my @hpart = ();

  while ($secs) {
    my $u  = $secs % 60;
    my $un = pop @uname;
    unshift @part, $u;
    unshift @hpart, $u == 1 ? "$u $un" : "$u ${un}s" if $u;
    $secs = int( $secs / 60 );
  }

  return join ', ', @hpart;
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

sub date2epoch {
  my ( $self, $date ) = @_;
  my ( $y, $m, $d ) = $self->decode_date($date);
  return timegm 0, 0, 0, $d, $m - 1, $y;
}

sub day_name {
  my ( $self, $daynum ) = @_;
  return unless $daynum >= 1 && $daynum <= 7;
  return $DAY_FULL[$daynum - 1];
}

sub day_for_date {
  my ( $self, $tm ) = @_;
  my @tm = gmtime( $tm // 0 );
  return ( day => $DAY[$tm[6]], mday => $tm[3] );
}

# If @years is supplied it's a list of hashes each of which contain a
# year key.
sub decade_list {
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
  return $self->decade_list( YEAR_START, YEAR_END );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
