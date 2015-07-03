package Lintilla::Site::Labs::Collection;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Collection;

=head1 NAME

Lintilla::Site::Labs::Collection - Run potted queries

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Collection->new( dbh => database ) }

prefix '/labs' => sub {

  get '/collections' => sub {
    template 'labs/collections',
     {title   => 'Labs Collections',
      scripts => ['collection'],
      css     => ['collection'],
     },
     { layout => 'labs2' };
  };

  get '/collections/:collection/data/:order/:start/:size' => sub {
    db->list(param('collection'), param('order'), param('start'), param('size'));
  };

  get '/collections/**' => sub {
    forward '/labs/collections';
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
