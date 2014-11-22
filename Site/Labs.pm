package Lintilla::Site::Labs;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Encode qw( decode encode );
use JSON ();
use Lintilla::DB::Genome::Edit;
use Lintilla::DB::Genome::Pages;
use Lintilla::DB::Genome::Schedule;
use Lintilla::DB::Genome::SocialGraph;
use Lintilla::DB::Genome::Stats;
use Lintilla::Magic::Asset;
use Path::Class;

=head1 NAME

Lintilla::Site::Labs - Labs stuff

=cut

our $VERSION = '0.1';

sub dbp() { Lintilla::DB::Genome::Pages->new( dbh => database ) }
sub dbe() { Lintilla::DB::Genome::Edit->new( dbh => database ) }
sub dbso() { Lintilla::DB::Genome::SocialGraph->new( dbh => database ) }

sub dbs { Lintilla::DB::Genome::Stats->new( dbh => database, @_ ) }

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

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

  get '/livestats' => sub {
    template 'labs/livestats',
     {title        => 'Genome Live Stats',
      scripts      => ['onstopped', 'livestats'],
      css          => ['livestats'],
      edit_counts  => dbe->edit_state_count,
      change_count => dbe->change_count,
     },
     { layout => 'labs' };
  };

  prefix '/livestats' => sub {
    get '/edit_counts' => sub {
      return { edit_counts => dbe->edit_state_count };
    };
    get '/count' => sub {
      return { change_count => dbe->change_count };
    };
  };

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
      return dbs->limits;
    };
    get '/range/:quantum/:from/:to' => sub {
      return dbs( quantum => param('quantum') )
       ->range_series( param('from'), param('to') );
    };
    get '/delta/:quantum/:from/:to' => sub {
      return dbs( quantum => param('quantum') )
       ->delta_series( param('from'), param('to') );
    };
  };

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
    get '/search/:limit' =>
     sub { dbso->search( param('q'), param('limit') ) };
    get '/graph/:limit/:id' =>
     sub { dbso->graph( param('id'), param('limit') ) };
    get '/random' => sub { dbso->random };
    get '/**' => $get_social;
  };

  get '/pages' => sub {
    delete request->env->{SCRIPT_NAME};
    redirect "/labs/pages/";
  };

  prefix '/pages' => sub {
    prefix '/data' => sub {
      get '/:issue' => sub { return dbp->pages( param('issue') ) };
      get '/:issue/:page' =>
       sub { return dbp->page( param('issue'), param('page') ) };
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

  # Dynamic schedule chunks
  prefix '/var/schedule' => sub {
    get '/week/:slot' => sub {
      die "Bad slot" unless param('slot') =~ /^(-?\d+)\.json$/;
      my $slot     = $1;
      my @path     = ( 'labs', 'var', 'schedule', 'week', "$slot.json" );
      my $out_file = file setting('public'), @path;

      my $sched = Lintilla::DB::Genome::Schedule->new(
        slot     => $slot,
        out_file => $out_file,
        dbh      => database
      );

      my $magic = Lintilla::Magic::Asset->new(
        filename => $out_file,
        timeout  => 20,
        provider => $sched,
        method   => 'create_week'
      );

      $magic->render or die "Can't render";

      my $self = our_uri_for(@path) . '?1';
      return redirect $self, 307;

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
