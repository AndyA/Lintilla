package Lintilla::Site::Edit;

use Moose;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use JSON qw();
use Lintilla::Broadcast::Client;
use Lintilla::Broadcast::Server;
use Lintilla::DB::Genome::Edit;
use Time::HiRes qw( time );

=head1 NAME

Lintilla::Site::Edit - Editing endpoints

=cut

our $VERSION = '0.1';

my $CLIENT = Lintilla::Broadcast::Client->new;
my $SERVER = Lintilla::Broadcast::Server->new->listen;

sub db() {
  my $db = Lintilla::DB::Genome::Edit->new( dbh => database );
  $db->on_bump(
    sub {
      my $path = shift;
      debug "Bumped $path";
      $CLIENT->send( { path => $path } );
    }
  );
  return $db;
}

prefix '/edit' => sub {
  post '/programme/:uuid' => sub {
    my $uuid = param('uuid');
    my $data = JSON->new->decode( request->body );
    db->submit( $uuid, 'programme', 'anon', $data );
    return { status => 'OK' };
  };
};

prefix '/admin' => sub {

  # Data services
  #
  get '/message/:serial' => sub {

    my $deadline = time + 10;

    while () {
      my $dc     = db->get_data_counts;
      my $serial = $dc->{ROOT};

      if ( $serial > param('serial') ) {
        debug "Serial updated: $serial";
        return {
          name   => 'CHANGE',
          serial => $serial,
          data   => $dc,
        };
      }

      my $remain = $deadline - time;
      last if $remain <= 0;

      debug "Serial not updated: $serial, waiting $remain";

      my $msg = $SERVER->poll($remain);
      debug "Got message: ", $msg if defined $msg;
    }

    return { name => 'PING', serial => param('serial') };

  };

  get '/list/stash' => sub {
    return db->list_stash;
  };

  get '/list/comment/:state/:start/:size/:order' => sub {
    return {};
  };

  get '/list/:kind/:state/:start/:size/:order' => sub {
    return {
      list => db->list(
        param('kind'), param('state'), param('start'), param('size'),
        param('order'),
      ),
      count => db->edit_state_count
    };
  };

  get '/diff/:id' => sub {
    return db->diff( param('id') );
  };

  prefix '/edit' => sub {
    post '/workflow/:id/:action' => sub {
      return db->workflow( param('id'), 'admin', param('action') );
    };
  };

  # Pages
  #
  get '/' => sub {
    delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
    redirect '/admin/approve';
  };

  get '/approve' => sub {
    delete request->env->{SCRIPT_NAME};   # don't include disptch.fcgi in URI
    redirect '/admin/approve/queue/pending/1/-updated';
  };

  get '/approve/**' => sub {
    template 'admin/approve',
     { title => 'Genome Admin', scripts => ['approve'] },
     { layout => 'admin' };
  };

  get '/copy' => sub {
    template 'admin/copy', { title => 'Genome Admin', scripts => ['copy'] },
     { layout => 'admin' };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
