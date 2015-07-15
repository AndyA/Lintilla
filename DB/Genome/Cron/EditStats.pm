package Lintilla::DB::Genome::Cron::EditStats;

use Moose;

use List::Util qw( min max );

=head1 NAME

Lintilla::DB::Genome::Cron::EditStats - Update edit stats

=cut

our $VERSION = '0.1';

with 'Lintilla::Role::DB';

use constant QUANTUM => 3600;
use constant NSTATE  => 4;

sub cron {
  my $self = shift;

  my %state     = ();
  my @bind      = ();
  my $cur_quant = undef;

  my ($max_slot)
   = $self->dbh->selectrow_array(
    'SELECT UNIX_TIMESTAMP(`slot`) FROM genome_editstats ORDER BY `slot` DESC LIMIT 1'
   );

  if ( defined $max_slot ) {
    %state = %{ $self->_load_slot( $max_slot - QUANTUM ) };
    push @bind, $max_slot;
    $cur_quant = int( $max_slot / QUANTUM );
  }

  my $get = $self->dbh->prepare(
    join ' ',
    'SELECT UNIX_TIMESTAMP(`when`) AS `when`, `old_state`, `new_state`',
    'FROM genome_editlog',
    ( defined $max_slot ? ('WHERE `when` >= FROM_UNIXTIME(?)') : () ),
    'ORDER BY `when` ASC'
  );

  my $flush = sub {
    my $quant = shift;
    if ( defined $quant ) {
      my $slot = $quant * QUANTUM;
      my @rows
       = map { { slot => $slot, state => $_, count => max( $state{$_}, 0 ) } }
       keys %state;
      $self->transaction(
        sub {
          $self->dbh->do(
            'DELETE FROM genome_editstats WHERE `slot` = FROM_UNIXTIME(?)',
            {}, $slot );
          $self->_insert( 'genome_editstats', @rows );
        }
      );
    }
  };

  $get->execute(@bind);
  while ( my $event = $get->fetchrow_hashref ) {
    my $quant = int( $event->{when} / QUANTUM );

    unless ( defined $cur_quant && $cur_quant == $quant ) {
      if ( defined $cur_quant ) {
        for ( my $qq = $cur_quant; $qq < $quant; $qq++ ) {
          $flush->($qq);
        }
      }
      $cur_quant = $quant;
    }

    $state{ $event->{old_state} }-- if defined $event->{old_state};
    $state{ $event->{new_state} }++ if defined $event->{new_state};
  }
  $flush->($cur_quant);
}

sub _load_slot {
  my ( $self, $slot ) = @_;
  my $stats = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `state`, `count`',
      'FROM genome_editstats',
      'WHERE `slot` = FROM_UNIXTIME(?)' ),
    { Slice => {} },
    $slot
  );
  my $st = {};
  $st->{ $_->{state} } = $_->{count} for @$stats;
  return $st;
}

sub _col_ins_expr {
  my ( $self, $col ) = @_;
  return '?' unless $col eq 'slot';
  return 'FROM_UNIXTIME(?)';
}

sub _insert {
  my ( $self, $tbl, @rows ) = @_;
  return unless @rows;
  my @cols = sort keys %{ $rows[0] };
  my $vals
   = '(' . join( ', ', map { $self->_col_ins_expr($_) } @cols ) . ')';
  $self->dbh->do(
    join( ' ',
      "INSERT INTO `$tbl` (",
      join( ', ', map "`$_`", @cols ),
      ") VALUES",
      join( ', ', ($vals) x @rows ) ),
    {},
    map { ( @{$_}{@cols} ) } @rows
  );
}

1;
