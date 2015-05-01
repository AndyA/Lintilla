package Lintilla::DB::Genome::Comments;

use v5.10;

use Moose;
use Dancer qw( :syntax );
use UUID::Tiny ':std';

our $VERSION = '0.1';

with 'Lintilla::Role::DB';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::DataCounter';
with 'Lintilla::Role::UUID';

=head1 NAME

Lintilla::DB::Genome::Comments - Handle comments

=cut

sub comments {
  my ( $self, @parent ) = @_;
}

sub add_comment {
  my ( $self, $parent, $cdata ) = @_;
  my $comment = {
    _uuid   => $self->create_uuid,
    _parent => $parent,
    state   => 'active',
    %$cdata
  };
}

sub _set_state {
  my ( $self, $uuid, $state ) = @_;
  $self->dbh->do( 'UPDATE genome_comments SET state=? WHERE _uuid=?',
    {}, $state, $uuid );
}

sub remove_comment {
  my ( $self, $uuid ) = @_;
  $self->_set_state( $uuid, 'deleted' );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
