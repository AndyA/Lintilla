package Lintilla::Site::Debug;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Debug;

=head1 NAME

Lintilla::Site::Debug - Debug info

=cut

our $VERSION = '0.1';

return 1 unless config->{debug_script};

sub db() {
  my $dbh = database;
  Lintilla::DB::Genome::Debug->new( dbh => $dbh );
}

prefix '/debug' => sub {
  get '/stash' => sub {
    db->debug_stash;
  };
  get '/utf8' => sub {
    template 'db/utf8',
     {title => 'UTF8 Test',
      stash => db->debug_stash,
     },
     { layout => 'debug' };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
