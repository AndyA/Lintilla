package Lintilla::Data;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;

=head1 NAME

Lintilla::Data - Data handlers

=cut

my %REF = map { $_ => 1 } qw(
 collection copyright_class copyright_holder format kind location
 news_restriction personality photographer subject
);

sub refdata {
  my $name = shift;
  die "Bad refdata name $name" unless $REF{$name};
  database->selectall_hashref( "SELECT id, name FROM elvis_$name", 'id' );
}

prefix '/data' => sub {
  get '/ref/:name' => sub {
    return refdata( param('name') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
