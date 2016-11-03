package Lintilla::Site::Labs::Social;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Labs::Factory;

=head1 NAME

Lintilla::Site::Labs::Social - Social graph

=cut

our $VERSION = '0.1';

sub db() { Labs::Factory->socialgraph_model }

prefix '/labs' => sub {

  my $get_social = sub {
    template 'labs/social',
     {title   => 'Genome Contributor Graph',
      scripts => ['arbor', 'arbor-tween', 'app', 'social'],
      css     => ['social'],
     },
     { layout => 'labs' };
  };

  get '/social' => $get_social;

  prefix '/social' => sub {
    get '/search/:limit' => sub { db->search( param('q'), param('limit') ) };
    get '/graph/:limit/:id' =>
     sub { db->graph( param('id'), param('limit') ) };
    get '/random' => sub { db->random };
    get '/**' => $get_social;
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
