package Lintilla::Site::Labs;

use Dancer ':syntax';

use Lintilla::Site::Labs::Collection;
use Lintilla::Site::Labs::Explorer;
use Lintilla::Site::Labs::Livestats;
use Lintilla::Site::Labs::Pages;
use Lintilla::Site::Labs::Schedule;
use Lintilla::Site::Labs::Social;
use Lintilla::Site::Labs::Stats;

=head1 NAME

Lintilla::Site::Labs - Labs stuff

=cut

our $VERSION = '0.1';

prefix '/labs' => sub {

  get '/' => sub {
    template 'labs/about',
     {title   => 'Genome Labs',
      scripts => [],
      css     => ['about'],
     },
     { layout => 'labs' };
  };

  get '/coverage' => sub {
    template 'labs/coverage',
     {title   => 'Genome Schedule Coverage',
      scripts => ['scaler', 'onstopped', 'edgescroll', 'coverage'],
      css     => ['coverage'],
     },
     { layout => 'labs' };
  };

  get '/*.html' => sub {
    delete request->env->{SCRIPT_NAME};
    my ($url) = splat;
    redirect "/labs/$url";
   }
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
