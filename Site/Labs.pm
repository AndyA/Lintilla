package Lintilla::Site::Labs;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Encode qw( decode encode );
use JSON ();
use Lintilla::DB::Genome::Pages;

=head1 NAME

Lintilla::Site::Labs - Labs stuff

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Pages->new( dbh => database ) }

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

  get '/pages' => sub {
    delete request->env->{SCRIPT_NAME};
    redirect "/labs/pages/";
  };

  prefix '/pages' => sub {
    prefix '/data' => sub {
      get '/:issue' => sub { return db->pages( param('issue') ) };
      get '/:issue/:page' =>
       sub { return db->page( param('issue'), param('page') ) };
    };

    get '/**' => sub {
      template 'labs/pages',
       {title   => 'Radio Times Page Layout',
        scripts => ['scaler', 'pages'],
        css     => ['pages'],
       },
       { layout => 'labs' };
    };
  };

  get '/*.html' => sub {
    delete request->env->{SCRIPT_NAME};
    my ($url) = splat;
    redirect "/labs/$url";
   }
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
