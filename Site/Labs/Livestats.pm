package Lintilla::Site::Labs::Livestats;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Genome::Factory;

=head1 NAME

Lintilla::Site::Labs::Livestats - Live edit stats

=cut

our $VERSION = '0.1';

sub db() { Genome::Factory->edit_model }

prefix '/labs' => sub {

  get '/livestats' => sub {
    template 'labs/livestats',
     {title        => 'Genome Live Stats',
      scripts      => ['onstopped', 'livestats'],
      css          => ['livestats'],
      edit_counts  => db->edit_state_count,
      change_count => db->change_count,
     },
     { layout => 'labs' };
  };

  prefix '/livestats' => sub {
    get '/edit_counts' => sub {
      return { edit_counts => db->edit_state_count };
    };
    get '/count' => sub {
      return { change_count => db->change_count };
    };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
