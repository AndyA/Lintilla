package Lintilla::Site::Sync;

use Dancer ':syntax';
use Dancer::Plugin::Database;

use Lintilla::DB::Genome::Edit;

=head1 NAME

Lintilla::Site::Sync - Sync endpoints

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Edit->new( dbh => database ) }

prefix '/sync' => sub {
  get '/changes/:since' => sub {
    db->load_changes( param('since') );
  };

  get '/edits/:since' => sub {
    db->load_edits( param('since') );
  };

  if ( config->{admin_mode} ) {
    post '/edits' => sub {
      my $db    = db;
      my $edits = $db->_decode( request->body );
      $db->import_edits($edits);
      return { status => 'OK', sequence => $edits->{sequence} };
    };
  }
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
