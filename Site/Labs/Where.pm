package Lintilla::Site::Labs::Where;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Where;

=head1 NAME

Lintilla::Site::Labs::where - Run potted queries

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Where->new( dbh => database ) }

prefix '/labs' => sub {

  get '/where' => sub {
    template 'labs/where',
     {title   => 'Genome Queries',
      scripts => ['where'],
      css     => ['where'],
     },
     { layout => 'labs2' };
  };

  get '/where/data/:query/:start/:size' => sub {
    db->where(param('query'), param('start'), param('size'));
  };

  get '/where/:query/:start/:size' => sub {
    forward '/labs/where';
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
