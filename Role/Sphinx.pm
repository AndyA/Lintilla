package Lintilla::Role::Sphinx;

use Moose::Role;

use Dancer qw( config );
use Sphinx::Search;

=head1 NAME

Lintilla::Role::Sphinx - A Sphinx Search

=cut

has sphinx => ( is => 'ro', lazy => 1, builder => '_b_sphinx' );

sub _b_sphinx {
  my $self = shift;
  my $sph  = Sphinx::Search->new();

  my $host = config->{sphinx_host} // 'localhost';
  my $port = config->{sphinx_port} // '9312';

  $sph->SetServer( $host, $port );
  return $sph;
}


1;
