package Lintilla::Site::Labs;

use Moose;

use Dancer ':syntax';

=head1 NAME

Lintilla::Site::Labs - Labs stuff

=cut

our $VERSION = '0.1';

prefix '/labs' => sub {

  get '/about' => sub {
    template 'labs/about',
     {title   => 'About Genome Labs',
      scripts => [],
      css     => [],
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
