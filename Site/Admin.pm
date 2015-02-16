package Lintilla::Site::Admin;

use v5.10;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use JSON qw();
use Lintilla::Broadcast::Client;
use Lintilla::Broadcast::Server;
use Lintilla::DB::Genome::Edit;
use Lintilla::Tools::Enqueue;
use Time::HiRes qw( time );

=head1 NAME

Lintilla::Site::Admin - Editing endpoints

=cut

our $VERSION = '0.1';

my $CLIENT = Lintilla::Broadcast::Client->new;
my $SERVER = Lintilla::Broadcast::Server->new->listen;

sub resources {
  return state $res ||= Lintilla::Tools::Enqueue->new(
    inherit => Lintilla::Site->resources,
    map     => {
      css => {
        admin2 => { url => '/admin2/css/admin2.css' },
        jquery_labeledslider =>
         { url => '/admin2/css/jquery.ui.labeledslider.css' },
      },
      js => {
        uri       => { url => '/admin2/js/URI.js' },
        diff_lcs  => { url => '/admin2/js/diff-lcs.js' },
        jquery_hotkeys => {
          url      => '/admin2/js/jquery.hotkeys.js',
          requires => ['js.jquery']
        },
        jquery_labeledslider => {
          url      => '/admin2/js/jquery.ui.labeledslider.min.js',
          requires => ['css.jquery_labeledslider', 'js.jquery_ui']
        },
        util => {
          url      => '/admin2/js/util.js',
          requires => ['js.jquery']
        },
        scroller => {
          url      => '/admin2/js/scroller.js',
          requires => ['js.jquery']
        },
        progress => {
          url      => '/admin2/js/progress.js',
          requires => ['js.spin', 'js.jquery']
        },
        datawatcher => {
          url      => '/admin2/js/datawatcher.js',
          requires => ['js.jquery', 'js.ev']
        },
        ev => {
          url      => '/admin2/js/ev.js',
          requires => ['js.jquery']
        },
        htmldiff => {
          url      => '/admin2/js/htmldiff.js',
          requires => ['js.jquery']
        },
        programme => {
          url      => '/admin2/js/programme.js',
          requires => ['js.jquery']
        },
        versions => {
          url => '/admin2/js/versions.js',
          requires =>
           ['js.jquery', 'js.jquery_labeledslider', 'js.textdiff', 'js.htmldiff']
        },
        textdiff => {
          url      => '/admin2/js/textdiff.js',
          requires => ['js.diff_lcs']
        },
        app => {
          url      => '/admin2/js/app.js',
          requires => ['js.jquery']
        },
        adminapp => {
          url      => '/admin2/js/adminapp.js',
          requires => ['js.jquery', 'js.datawatcher', 'js.app']
        },
        wysihtml5_parser_rules =>
         { url => '/admin2/js/wysihtml5/parser_rules/advanced.js' },
        wysihtml5 => {
          url      => '/admin2/js/wysihtml5/wysihtml5-0.3.0.min.js',
          requires => ['js.wysihtml5_parser_rules']
        },
        approve => {
          url      => '/admin2/js/approve.js',
          requires => [
            'js.jquery',         'js.adminapp', 'js.programme', 'js.versions',
            'js.util',           'js.progress', 'js.uri',       'js.scroller',
            'js.jquery_hotkeys', 'css.fa'
          ]
        },
      } }
  );
}

sub db() {
  my $db = Lintilla::DB::Genome::Edit->new( dbh => database );
  $db->on_bump(
    sub {
      my $path = shift;
      $CLIENT->send( { path => $path } );
    }
  );
  return $db;
}

sub check_vis {
  my ( $need, $cb ) = @_;
  return sub {
    my $vis = vars->{personality}->personality;
    if   ( $vis eq $need ) { $cb->(@_); }
    else                   { send_error( "Not allowed", 403 ); }
  };
}

return 1 unless config->{admin_mode};

prefix '/admin2' => sub {

  # Data services
  #
  get '/message/:serial' => check_vis(
    'internal',
    sub {

      my $deadline = time + 10;
      my $max      = 1;

      while () {
        my $dc     = db->get_data_counts;
        my $serial = $dc->{ROOT};

        if ( $serial > param('serial') ) {
          return {
            name   => 'CHANGE',
            serial => $serial,
            data   => $dc,
          };
        }

        my $remain = $deadline - time;
        $remain = $max if $remain > $max;
        last if $remain <= 0;

        my $msg = $SERVER->poll($remain);
      }

      return { name => 'PING', serial => param('serial') };

    }
  );

  get '/list/:kind/:state/:start/:size/:order/near/:edit_id' => check_vis(
    'internal',
    sub {
      my %params = params;
      my $row = db->find_edit_in_list(%params) // 0;
      $params{start} = int( $row / $params{size} ) * $params{size};

      return {
        start => $params{start},
        size  => $params{size},
        limit => db->count_for_list_query(%params),
        list  => db->list_v2(%params),
        count => db->edit_state_count
      };
    }
  );

  get '/list/:kind/:state/:start/:size/:order' => check_vis(
    'internal',
    sub {
      my %params = params;

      my $limit = db->count_for_list_query(%params);
      $params{start} = int( $limit / $params{size} ) * $params{size}
       if $params{start} >= $limit;

      return {
        start => $params{start},
        size  => $params{size},
        limit => $limit,
        list  => db->list_v2(%params),
        count => db->edit_state_count
      };
    }
  );

  prefix '/edit' => sub {
    post '/workflow/:id/:action' => check_vis(
      'internal',
      sub {
        return db->workflow( param('id'), 'admin', param('action') );
      }
    );
    post '/edit/:id' => check_vis(
      'internal',
      sub {
        my $db   = db;
        my $data = $db->_decode( request->body );
        $db->edit_edit( param('id'), 'admin', $data );
        return { status => 'OK', message => 'Successfully edited' };
      }
    );
  };

  # Pages
  #
  get '/' => check_vis(
    'internal',
    sub {
      delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
      redirect '/admin2/approve';
    }
  );

  get '/approve' => check_vis(
    'internal',
    sub {
      delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
      redirect '/admin2/approve/programme/pending/1/-updated';
    }
  );

  get '/approve/**' => check_vis(
    'internal',
    sub {
      template 'admin2/approve',
       {title => 'Genome Admin',
        resources => resources->render( 'js.approve', 'css.admin2' ),
       },
       { layout => 'admin2' };
    }
  );
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
