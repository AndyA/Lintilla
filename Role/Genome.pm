package Lintilla::Role::Genome;

use Moose::Role;

=head1 NAME

Lintilla::Role::Genome - Common Genome DB functionality

=cut

requires 'dbh';
requires 'format_uuid';

sub lookup_uuid {
  my ( $self, $uuid ) = @_;
  my @row
   = $self->dbh->selectrow_hashref( 'SELECT * FROM dirty WHERE uuid=?',
    {}, $self->format_uuid($uuid) );
  return unless @row;
  return $row[0];
}

sub lookup_kind {
  my ( $self, $uuid ) = @_;
  my $thing = $self->lookup_uuid($uuid);
  return unless $thing;
  return $thing->{kind};
}

sub clean_id {
  my ( $self, $uuid ) = @_;
  $uuid =~ s/-//g;
  return $uuid;
}

sub site_name { 'BBC Genome' }

sub page_title {
  my ( $self, @title ) = @_;
  return join ' - ', @title, $self->site_name;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
