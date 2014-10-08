package Lintilla::Site::Data;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Genome;

=head1 NAME

Lintilla::Data - Data handlers

=cut

prefix '/data' => sub {
  get '/services' => sub {
    Lintilla::DB::Genome->new( dbh => database )->services;
  };
  get '/years' => sub {
    Lintilla::DB::Genome->new( dbh => database )->years;
  };
  get '/decades' => sub {
    Lintilla::DB::Genome->new( dbh => database )->decades;
  };
  get '/programme/:uuid' => sub {
    Lintilla::DB::Genome->new( dbh => database )->programme( param('uuid') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
