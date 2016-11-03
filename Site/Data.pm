package Lintilla::Site::Data;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Genome::Factory;

=head1 NAME

Lintilla::Data - Data handlers

=cut

prefix '/data' => sub {
  get '/services' => sub {
    Genome::Factory->model->services;
  };
  get '/years' => sub {
    Genome::Factory->model->years;
  };
  get '/decades' => sub {
    Genome::Factory->model->decades;
  };
  get '/programme/:uuid' => sub {
    Genome::Factory->model->programme( param('uuid') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
