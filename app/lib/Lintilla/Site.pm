package Lintilla::Site;

use Dancer ':syntax';

use Lintilla::Site::Asset;
use Lintilla::Site::Data;

our $VERSION = '0.1';

get '/' => sub {
  template 'index', { ds => request->uri_for('/data/page/:size/:start') };
};

get '/search' => sub {
  template 'index',
   { ds =>
     request->uri_for( '/data/search/:size/:start', { q => param('q') } ) };
};

true;
