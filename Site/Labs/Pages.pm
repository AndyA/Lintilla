package Lintilla::Site::Labs::Pages;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Pages;

=head1 NAME

Lintilla::Site::Labs::Pages - OCR Page regions

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Pages->new( dbh => database ) }

prefix '/labs' => sub {

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

};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
