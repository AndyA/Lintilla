package Lintilla::Site::Edit;

use Moose;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use JSON qw();
use Lintilla::DB::Genome::Edit;

=head1 NAME

Lintilla::Site::Edit - Editing endpoints

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Edit->new( dbh => database ) }

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
    sleep 5;
    return { name => 'PING', serial => param('serial') + 1 };
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
  for my $path ( '/', '/detail/:id' ) {
    get $path => sub {
      template 'admin/edits', { title => 'Genome Admin', scripts => ['edit'] },
       { layout => 'admin' };
    };
  }

  get '/approve/**' => sub {
    template 'admin/approve',
     { title => 'Genome Admin', scripts => ['app', 'adminapp', 'approve'] },
     { layout => 'admin' };
  };

  get '/copy' => sub {
    template 'admin/copy', { title => 'Genome Admin', scripts => ['copy'] },
     { layout => 'admin' };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
