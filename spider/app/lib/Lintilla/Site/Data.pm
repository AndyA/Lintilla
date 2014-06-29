package Lintilla::Site::Data;

use Moose;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Lintilla::DB::Spider;

=head1 NAME

Lintilla::Data - Data handlers

=cut

prefix '/data' => sub {
  get '/search/:size/:start' => sub {
    my $db = Lintilla::DB::Spider->new( dbh => database );
    return $db->search( param('start'), param('size'), param('q') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
