package Lintilla::Site::Labs::Stats;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Stats;

=head1 NAME

Lintilla::Site::Labs::Stats - Digested stats graphs

=cut

our $VERSION = '0.1';

sub db { Lintilla::DB::Genome::Stats->new( dbh => database, @_ ) }

prefix '/labs' => sub {

  get '/stats' => sub {
    template 'labs/stats',
     {title   => 'Genome Edit Stats',
      scripts => ['stats', 'Chart.min'],
      css     => ['stats'],
     },
     { layout => 'labs' };
  };

  prefix '/stats' => sub {
    get '/limits' => sub {
      return db->limits;
    };
    get '/range/:quantum/:from/:to' => sub {
      return db( quantum => param('quantum') )
       ->range_series( param('from'), param('to') );
    };
    get '/delta/:quantum/:from/:to' => sub {
      return db( quantum => param('quantum') )
       ->delta_series( param('from'), param('to') );
    };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
