package Lintilla::Role::UUID;

use Moose::Role;

use UUID::Tiny ':std';

=head1 NAME

Lintilla::Role::UUID - Handle UUIDs

=cut

sub make_uuid { create_uuid_as_string(UUID_V4) }

sub format_uuid {
  my ( $self, $uuid ) = @_;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

sub strip_uuid {
  my ( $self, $uuid ) = @_;
  # Format to validate
  ( my $stripped = $self->format_uuid($uuid) ) =~ s/-//g;
  return $stripped;
}

sub is_uuid {
  my ( $self, $str ) = @_;
  return $str =~ /^ ([0-9a-f]{8}) -
                    ([0-9a-f]{4}) -
                    ([0-9a-f]{4}) -
                    ([0-9a-f]{4}) -
                    ([0-9a-f]{12}) $/xi;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
