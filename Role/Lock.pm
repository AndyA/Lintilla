package Lintilla::Role::Lock;

use Moose::Role;

use POSIX qw( uname );
use Sys::Hostname;

=head1 NAME

Lintilla::Role::Lock - Database wide lock

=cut

requires 'dbh';

sub host_key {
  return join "-", $$, hostname;
}

sub _decode_host_key {
  my ( $self, $host_key ) = @_;
  return split /-/, $host_key;
}

sub _lock_key {
  my ( $self, @key ) = @_;
  return join "-", $self->blessed, @key;
}

sub _get_owner {
  my ( $self, $lock_name ) = @_;

  my ($owner)
   = $self->dbh->selectrow_array(
    "SELECT `locked_by` FROM `genome_distributed_lock` WHERE `name` = ?",
    {}, $lock_name );

  return $owner;
}

sub _with_lock {
  my ( $self, $code ) = @_;
  $self->dbh->do("LOCK TABLES `genome_distributed_lock` WRITE");
  my $rv = eval { $code->() };
  my $err = $@;
  $self->dbh->do("UNLOCK TABLES");
  die $err if $err;
  return $rv;
}

sub _process_valid {
  my ( $self, $pid ) = @_;

  if ( (uname)[0] eq "Linux" && -d "/proc" ) {
    return -d sprintf "/proc/%d", $pid;
  }

  # Fall back on kill - which also returns false if we don't
  # have permission to signal $pid
  return kill 0, $pid;
}

sub _lock_valid {
  my ( $self, $locked_by ) = @_;

  # NULL => not locked
  return unless defined $locked_by;

  # Locked by whom?
  my ( $pid, $host ) = $self->_decode_host_key($locked_by);

  # Different host - nothing we can do
  return 1 unless $host eq hostname;

  # This host so check whether the PID is a valid process.
  return unless $self->_process_valid($pid);

  return 1;
}

sub acquire_lock {
  my ( $self, @key ) = @_;
  my $lock_name = $self->_lock_key(@key);
  my $host_key  = $self->host_key;

  return $self->_with_lock(
    sub {
      my $locked_by = $self->_get_owner($lock_name);
      return if $self->_lock_valid($locked_by);

      $self->dbh->do(
        join( " ",
          "REPLACE INTO `genome_distributed_lock` (`name`, `locked_by`, `when`)",
          "VALUES (?, ?, NOW())" ),
        {},
        $lock_name,
        $host_key
      );

      return $host_key;
    }
  );
}

sub release_named_lock {
  my ( $self, $host_key, @key ) = @_;
  my $lock_name = $self->_lock_key(@key);

  $self->_with_lock(
    sub {
      my $locked_by = $self->_get_owner($lock_name);

      die
       "Attempt to release a lock we don't hold (expected $host_key, got $locked_by)"
       unless defined $locked_by && $locked_by eq $host_key;

      $self->dbh->do(
        join( " ",
          "UPDATE `genome_distributed_lock`",
          "SET `locked_by` = NULL, `when` = NOW()",
          "WHERE `name` = ? AND `locked_by` = ?" ),
        {},
        $lock_name,
        $host_key
      );
    }
  );

  return;
}

sub release_lock {
  my ( $self, @key ) = @_;
  return $self->release_named_lock( $self->host_key, @key );
}

1;
