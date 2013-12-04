package Lintilla::Site;

use Dancer ':syntax';

use Lintilla::Site::Asset;
use Lintilla::Site::Data;
use Path::Class;

our $VERSION = '0.1';

get '/' => sub {
  template 'index';
};

true;
