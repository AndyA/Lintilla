package Lintilla::Role::SphinxQL;

use Moose::Role;

use Dancer qw( config );
use Sphinx::Search;

=head1 NAME

Lintilla::Role::SphinxQL - A SphinxQL connection

=cut

our $VERSION = '0.1';

has sph => ( is => 'ro', isa => 'DBI::db' );

sub get_meta {
  my $self = shift;
  my $meta
   = $self->sph->selectall_arrayref( "SHOW META", { Slice => {} } );

  my $out      = {};
  my @keywords = ();

  for my $m (@$meta) {
    my ( $key, $value ) = @{$m}{ 'Variable_name', 'Value' };
    if ( $key =~ m{^(.+)\[(\d+)\]$} ) {
      $keywords[$2]{$1} = $value;
    }
    else {
      $out->{$key} = $value;
    }
  }
  $out->{keywords} = \@keywords;
  return $out;
}

1;
