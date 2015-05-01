package Lintilla::DB::Genome::Tags;

use v5.10;

use Carp qw( confess );
use Dancer qw( :syntax );
use Moose;

our $VERSION = '0.1';

with 'Lintilla::Role::DB';
with 'Lintilla::Role::JSON';

=head1 NAME

Lintilla::DB::Genome::Tags - do something

=cut

sub _table_for_kind {
  my ( $self, $kind ) = @_;
  state %kind_tbl = ( comment => 'genome_comment_tags' );

  confess "Unknown tag kind" unless $kind_tbl{$kind};
  return $kind_tbl{$kind};
}

sub get_uuid {
  my ( $self, $tag ) = @_;
}

sub add_tag_uuid {
  my ( $self, $kind, $tag_uuid ) = @_;
}

sub add_tag {
  my ( $self, $kind, $tag ) = @_;
  return $self->add_tag_uuid( $kind, $self->get_uuid($tag) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
