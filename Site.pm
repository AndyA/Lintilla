package Lintilla::Site;

use v5.10;
use Dancer ':syntax';

use Barlesque::Client;
use Dancer::Plugin::Database;
use Genome::Factory;
use Lintilla::DB::Genome::Search::Options;
use Lintilla::Data::Static;
use Lintilla::Personality;
use Lintilla::Site::Admin;
use Lintilla::Site::Asset;
use Lintilla::Site::Cron;
use Lintilla::Site::Data;
use Lintilla::Site::Edit;
use Lintilla::Site::Labs;
use Lintilla::Site::Page;
use Lintilla::Site::Sync;
use Lintilla::TT::Context;
use Lintilla::TT::Extensions;
use Path::Class;
use URI;

our $VERSION = '0.1';

=head1 NAME

Lintilla::Site - Genome main app

=cut

no if $] >= 5.018, warnings => "experimental::smartmatch";

use constant BOILERPLATE => qw(
 decade_years decades media_count month_names services share_stash
 short_month_names years
);

use constant URL_SHRINKER =>
 'http://www.bbc.co.uk/modules/share/service/shrink';

sub resources {
  return state $res ||= Lintilla::Tools::Enqueue->new(
    map => {
      css => {
        fa        => { url => '/css/font-awesome/css/font-awesome.min.css' },
        jquery_ui => { url => '/css/jquery-ui.min.css' },
      },
      js => {
        jquery    => { url => '/js/jquery-1.11.1.min.js' },
        jquery_ui => {
          url      => '/js/jquery-ui.min.js',
          requires => ['css.jquery_ui', 'js.jquery']
        },
        spin => { url => '/js/spin.min.js' },
      } }
  );
}

my $STATIC = Lintilla::Data::Static->new(
  store => dir( setting('appdir'), 'data' ) );

if ( config->{magic_context} ) {
  $Template::Config::CONTEXT = 'Lintilla::TT::Context';
}

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub is_tls {
  my $tls = request->env->{HTTP_X_TLS} // 'no';
  return $tls eq 'yes';
}

sub barlesque {
  Barlesque::Client->new(
    blq_doctype             => 'html5',
    blq_link_prefix         => 'http://www.bbc.co.uk',
    blq_version             => 4,
    blq_nedstat_countername => 'genome.test.page',
    blq_nedstat             => 1,
    ( is_tls() ? ( blq_https => 1 ) : () )
  );
}

sub clean_word {
  ( my $w = shift ) =~ s/\W//g;
  return 'unknown' unless length $w;
  return $w;
}

sub echo_key {
  my @path = @_;
  my $pe   = vars->{personality};
  return join '.', map { clean_word($_) } 'genome', $pe->personality,
   @path, 'page';
}

sub boilerplate() {
  my $srch = Lintilla::DB::Genome::Search::Options->new;
  my $pe   = vars->{personality};
  return (
    Genome::Factory->model->gather(BOILERPLATE),
    barlesque   => barlesque->parts,
    static_base => is_tls()
    ? 'https://static.bbc.co.uk'
    : 'http://static.bbci.co.uk',
    visibility     => $pe->personality,
    change_count   => Genome::Factory->edit_model->change_count,
    stash          => sub { Genome::Factory->model->stash(shift) },
    timelist       => sub { $srch->timelist },
    title          => Genome::Factory->model->page_title,
    stations       => $STATIC->get('stations'),
    form           => $srch->form,
    switchview     => $pe->switcher,
    show_external  => !config->{disable_external},
    infax_link     => !!config->{infax_link},
    related_merged => !!config->{show_related_merged},
    debug_script   => config->{debug_script},
    echo_key       => echo_key(),
    devmode        => !!config->{show_related_merged},
    capture_email  => !!config->{capture_email},
    blog           => Genome::Factory->blog_model->get_posts( "genome", 3 ),
  );
}

sub self {
  return request->scheme . '://' . request->host . request->request_uri;
}

hook 'before' => sub {
  my $vis = request->env->{HTTP_X_VISIBILITY} // 'external';
  my $rules = "switcher-$vis";
  var personality => Lintilla::Personality->new(
    url   => self(),
    rules => $STATIC->get($rules)
  );
};

get '/' => sub {
  template 'index', {boilerplate};
};

sub safe_service_defaults {
  my $service = shift;
  my @dflt = Genome::Factory->model->service_defaults( param('service') );
  return '/schedules/missing' unless @dflt;
  return join( '/', '/schedules', $service, @dflt );
}

get '/schedules/missing' => sub {
  template 'schedule',
   {boilerplate,
    missing  => 1,
    title    => Genome::Factory->model->page_title('Listing Unavailable'),
    echo_key => echo_key('missing'),
   };
};

get '/schedules/:service/near/:date' => sub {
  delete request->env->{SCRIPT_NAME};
  redirect join '/', '/schedules',
   Genome::Factory->model->service_near( param('service'), param('date') );
};

get '/schedules/:service' => sub {
  delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
  redirect safe_service_defaults( param('service') );
};

get '/schedules/:service/:date' => sub {
  my @dflt = Genome::Factory->model->service_defaults( param('service'),
    param('date') );
  if ( @dflt > 1 ) {
    delete request->env->{SCRIPT_NAME};
    redirect join '/', '/schedules', param('service'), @dflt;
    return;
  }
  template 'schedule',
   {boilerplate,
    echo_key => echo_key( 'schedule', param('service') ),
    Genome::Factory->model->listing_for_schedule(
      param('service'), param('date')
    ),
   };
};

get '/schedules/:service/:outlet/:date' => sub {
  template 'schedule',
   {boilerplate,
    echo_key => echo_key( 'schedule', param('service') ),
    Genome::Factory->model->listing_for_schedule(
      param('service'), param('outlet'), param('date')
    ),
   };
};

get '/years/:year' => sub {
  pass unless param('year') =~ /^\d+$/;
  template 'year',
   {boilerplate,
    echo_key => echo_key( 'year', param('year') ),
    Genome::Factory->model->issues_for_year( param('year') ),
   };
};

get '/issues' => sub {
  template 'issues',
   {boilerplate,
    echo_key => echo_key('issues'),
    Genome::Factory->model->annual_issues
   };
};

get '/search/:start/:size' => sub {
  template 'search',
   {boilerplate,
    echo_key => echo_key('search'),
    Genome::Factory->model->search(params) };
};

get '/search' => sub {
  delete request->env->{SCRIPT_NAME};
  my $uri = URI->new( request->uri_for('/search/0/20') );
  $uri->query_form(params);
  redirect $uri;
};

get '/help' => sub {
  template 'help',
   {boilerplate,
    echo_key    => echo_key('help'),
    share_stash => Genome::Factory->model->share_stash(
      title => 'FAQs for the BBC Genome Project'
    ),
    title => Genome::Factory->model->page_title('FAQs') };
};

get '/faqs' => sub {
  template 'help',
   {boilerplate,
    echo_key    => echo_key('faqs'),
    share_stash => Genome::Factory->model->share_stash(
      title => 'FAQs for the BBC Genome Project'
    ),
    title => Genome::Factory->model->page_title('FAQs') };
};

get '/about' => sub {
  template 'about',
   {boilerplate,
    echo_key    => echo_key('about'),
    share_stash => Genome::Factory->model->share_stash(
      title => 'About the BBC Genome Project'
    ),
    title => Genome::Factory->model->page_title('About this project') };
};

get '/style-guide' => sub {
  template 'style-guide',
   {boilerplate,
    echo_key    => echo_key('styleguide'),
    share_stash => Genome::Factory->model->share_stash(
      title => 'Editing Style Guide for BBC Genome'
    ),
    title => Genome::Factory->model->page_title('Editing Style Guide') };
};

get qr/\/([0-9a-f]{32})/i => sub {
  my ($uuid) = splat;
  my $thing = Genome::Factory->model->lookup_uuid($uuid);
  given ( $thing->{kind} ) {
    when ('issue') {
      template 'issue',
       {boilerplate,
        echo_key => echo_key('issue'),
        Genome::Factory->model->issue_listing($uuid) };
    }
    when ('programme') {
      template 'programme',
       {boilerplate,
        echo_key => echo_key('programme'),
        Genome::Factory->model->programme($uuid) };
    }
    default {
      pass;
    }
  }
};

# Redirect for URL shrinking

get '/modules/share/service/shrink' => sub {
  my $shrink = URI->new(URL_SHRINKER);
  $shrink->query_form(params);
  redirect $shrink;
};

# Must be last
any qr{.*} => sub {
  status 'not_found';
  template 'error404',
   {boilerplate,
    echo_key => echo_key('404'),
    path     => request->path
   };
};

true;
