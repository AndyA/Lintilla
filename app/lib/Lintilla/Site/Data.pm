package Lintilla::Site::Data;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;

=head1 NAME

Lintilla::Data - Data handlers

=cut

use constant MAX_PAGE => 500;

my %REF = map { $_ => 1 } qw(
 collection copyright_class copyright_holder format kind location
 news_restriction personality photographer subject
);

sub refdata {
  my $name = shift;
  die "Bad refdata name $name" unless $REF{$name};
  my $ref
   = database->selectall_hashref( "SELECT id, name FROM elvis_$name",
    'id' );
  $_ = $_->{name} for values %$ref;
  return $ref;
}

sub page {
  my ( $start, $size ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;
  database->selectall_arrayref(
    "SELECT * FROM elvis_image ORDER BY acno ASC LIMIT ?, ?",
    { Slice => {} },
    $start, $size
  );
}

prefix '/data' => sub {
  get '/ref/:name' => sub {
    return refdata( param('name') );
  };
  get '/page/:size/:start' => sub {
    return page( param('start'), param('size') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
