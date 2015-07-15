package Lintilla::DB::Genome::Cron;

use v5.10;

use Moose;

use Lintilla::Util qw( tidy );

our $VERSION = '0.1';

with 'Lintilla::Role::DB';
with 'Lintilla::Role::Lock';
with 'Lintilla::Role::JSON';

=head1 NAME

Lintilla::DB::Genome::Cron - Periodic tasks

=cut

=head2 C<< run >>

Run periodic jobs that are due. Each job is the name of a class which
will be instantiated (with a parameter dbh - the database handle) and
have its C<< cron >> method called.

=cut

sub run {
  my $self = shift;

  return { status => "LOCKED" } unless $self->acquire_lock;

  my $jobs = $self->dbh->selectall_arrayref(
    join( " ",
      "SELECT * FROM `genome_cron`",
      "WHERE `enabled`",
      "  AND (",
      "       `last_run` IS NULL ",
      "    OR DATE_ADD(`last_run`, INTERVAL `interval` MINUTE) <= NOW())" ),
    { Slice => {} }
  );
  for my $job (@$jobs) {
    eval { $self->run_job($job) };
    my ( $status, $message ) = ( 0, "OK" );
    ( $status, $message ) = ( 500, tidy($@) ) if $@;
    $self->dbh->do(
      join( " ",
        "INSERT INTO `genome_cron_log` (`name`, `when`, `status`, `message`)",
        "VALUES (?, NOW(), ?, ?)" ),
      {},
      $job->{name},
      $status, $message
    );
    $self->dbh->do(
      "UPDATE `genome_cron` SET `last_run` = NOW() WHERE `name` = ?",
      {}, $job->{name} );
  }

  $self->release_lock;

  return { status => "OK" };
}

=head2 C<< run_job >>

Run a cron job.

=cut

sub run_job {
  my ( $self, $job ) = @_;
  my $class = $job->{job};
  die "Bad job $class" unless $class =~ m{^\w+(?:::\w+)*$};
  eval {
    ( my $file = $class ) =~ s|::|/|g;
    require $file . '.pm';
    $class->import();
    1;
  };
  die $@ if $@;
  my $runner = $class->new( dbh => $self->dbh );
  my $config = $self->_decode_wide( $job->{config} );
  $runner->cron($config);
}

=head2 C<< cron >>

Our own periodic job. Cleans up old entries in genome_cron_log.

=cut

sub cron {
  my ( $self, $options ) = @_;
  $self->dbh->do(
    join( " ",
      "DELETE FROM `genome_cron_log`",
      "WHERE `when` < DATE_SUB(NOW(), INTERVAL ? DAY)" ),
    {},
    $options->{days}
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
