package Lintilla::Site::Edit;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Genome::Factory;
use JSON qw();
use Lintilla::Broadcast::Client;
use Lintilla::Broadcast::Server;
use Time::HiRes qw( time );

=head1 NAME

Lintilla::Site::Edit - Editing endpoints

=cut

our $VERSION = '0.1';

my $CLIENT = Lintilla::Broadcast::Client->new;
my $SERVER = Lintilla::Broadcast::Server->new->listen;

sub db() {
  my $db = Genome::Factory->edit_model;
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

prefix '/admin' => sub {

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

  get '/list/stash' => check_vis(
    'internal',
    sub {
      return db->list_stash;
    }
  );

  get '/list/:kind/:state/:start/:size/:order' => check_vis(
    'internal',
    sub {
      return {
        list  => db->list(params),
        count => db->edit_state_count
      };
    }
  );

  get '/list2/:kind/:state/:start/:size/:order' => check_vis(
    'internal',
    sub {
      return {
        list  => db->list_v2(params),
        count => db->edit_state_count
      };
    }
  );

  get '/diff/:id' => check_vis(
    'internal',
    sub {
      return db->diff( param('id') );
    }
  );

  get '/versions/:uuid' => check_vis(
    'internal',
    sub {
      return db->versions( param('uuid') );
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
      redirect '/admin/approve';
    }
  );

  get '/approve' => check_vis(
    'internal',
    sub {
      delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
      redirect '/admin/approve/queue/pending/1/-updated';
    }
  );

  get '/approve/**' => check_vis(
    'internal',
    sub {
      template 'admin/approve',
       {title   => 'Genome Admin',
        scripts => ['jquery.autosize.min', 'approve']
       },
       { layout => 'admin' };
    }
  );

  get '/copy' => check_vis(
    'internal',
    sub {
      template 'admin/copy', { title => 'Genome Admin', scripts => ['copy'] },
       { layout => 'admin' };
    }
  );
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
