package Lintilla::Role::Config;

use Moose::Role;

=head1 NAME

Lintilla::Role::Config - Read genome config

=cut

requires 'dbh';
requires '_decode';

has _config_cache => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub { {} },
);

sub _read_config {
  my ( $self, $name ) = @_;
  my ($val)
   = $self->dbh->selectrow_array(
    'SELECT `value` FROM genome_config WHERE `name`=?',
    {}, $name );
  return $self->_decode($val);
}

sub config {
  my ( $self, $name ) = @_;
  my $cache = $self->_config_cache;
  return $cache->{$name} //= $self->_read_config($name);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
