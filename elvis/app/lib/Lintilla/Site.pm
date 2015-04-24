package Lintilla::Site;

use Dancer ':syntax';

use Lintilla::Site::Asset;
use Lintilla::Site::Data;

our $VERSION = '0.1';

get '/' => sub {
  template 'index',
   { q => '', ds => request->uri_for('/data/page/:size/:start') };
};

get '/map/**' => sub {
  template 'map', {}, { layout => 'map' };
};

get '/search' => sub {
  my $q = param('q');
  template 'index',
   {q  => $q,
    ds => request->uri_for( '/data/search/:size/:start', { q => $q } ),
   };
};

get '/by/:field/:value' => sub {
  my $field = param('field');
  my $value = param('value');
  die unless $field =~ /^\w+$/;
  die unless $value =~ /^\d+$/;
  template 'index',
   {q  => '',
    ds => request->uri_for("/data/by/:size/:start/$field/$value"),
   };
};

get '/tag/:id' => sub {
  my $id = param('id');
  die unless $id =~ /^\d+$/;
  template 'index',
   {q  => '',
    ds => request->uri_for("/data/tag/:size/:start/$id"),
   };
};

get '/debug/stats' => sub {
  template 'debug', {}, { layout => 'debug' };
};

true;
