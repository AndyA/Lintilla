package Lintilla::Role::Lock;

use Moose::Role;

use Sys::Hostname;

=head1 NAME

Lintilla::Role::Lock - Database wide lock

=cut

requires 'dbh';

has host_key => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  builder => '_b_host_key'
);

sub _b_host_key {
  return join "-", $$, hostname;
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

sub acquire_lock {
  my ( $self, @key ) = @_;
  my $lock_name = $self->_lock_key(@key);
  my $host_key  = $self->host_key;

  return $self->_with_lock(
    sub {
      my $locked_by = $self->_get_owner($lock_name);
      return if defined $locked_by;

      $self->dbh->do(
        join( " ",
          "REPLACE INTO `genome_distributed_lock` (`name`, `locked_by`, `when`)",
          "VALUES (?, ?, NOW())" ),
        {},
        $lock_name,
        $host_key
      );

      return 1;
    }
  );
}

sub release_lock {
  my ( $self, @key ) = @_;
  my $lock_name = $self->_lock_key(@key);
  my $host_key  = $self->host_key;

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

1;
