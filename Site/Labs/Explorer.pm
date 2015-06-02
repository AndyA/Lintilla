package Lintilla::Site::Labs::Explorer;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Explorer;

=head1 NAME

Lintilla::Site::Labs::Explorer - Schedule explorer

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Explorer->new( dbh => database ) }

prefix '/labs' => sub {

  get '/explorer' => sub {
    template 'labs/explorer',
     {title   => 'Genome Schedule Explorer',
      scripts => ['explorer'],
      css     => ['explorer'],
     },
     { layout => 'labs2' };
  };

  prefix '/explorer/data' => sub {
    get '/services' => sub { db->service_info };
    get '/year/:uuid/:year' => sub {
      db->service_year( param('uuid'), param('year') );
    };
  };

};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
