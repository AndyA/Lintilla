package Lintilla::Site::Debug;

use Moose;

use Dancer ':syntax';

=head1 NAME

Lintilla::Site::Debug - Debug info

=cut

our $VERSION = '0.1';

sub non_ref {
  my $v = shift;
  return $v unless ref $v;
  return [map { non_ref($_) } @$v] if 'ARRAY' eq ref $v;
  return { map { $_ => non_ref( $v->{$_} ) } keys %$v }
   if 'HASH' eq ref $v;
  return "$v";
}

prefix '/peek' => sub {
  get '/request' => sub {
    return {
      env     => non_ref( request->env ),
      headers => request->{headers}->as_string,
    };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
