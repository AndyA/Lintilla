package Lintilla::Site::Diagnostic;

use v5.10;
use Dancer ':syntax';

=head1 NAME

Lintilla::Site::Diagnostic - Site diagnostics

=cut

sub non_ref {
  my $v = shift;
  return $v unless ref $v;
  return [map { non_ref($_) } @$v] if 'ARRAY' eq ref $v;
  return { map { $_ => non_ref( $v->{$_} ) } keys %$v }
   if 'HASH' eq ref $v;
  return "$v";
}

prefix '/diag' => sub {
  get '/ajax' => sub {
    template 'diag/ajax', { title => 'AJAX Test', }, { layout => 'diag' };
  };

  any '/endpoint' => sub {
    return non_ref { %{ request() } };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
