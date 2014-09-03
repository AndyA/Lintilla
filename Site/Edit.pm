package Lintilla::Site::Edit;

use Moose;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use JSON qw();
use Lintilla::DB::Genome::Edit;

=head1 NAME

Lintilla::Site::Edit - Editing endpoints

=cut

our $VERSION = '0.1';

sub db() { Lintilla::DB::Genome::Edit->new( dbh => database ) }

prefix '/edit' => sub {
  post '/programme/:uuid' => sub {
    my $uuid = param('uuid');
    my $data = JSON->new->decode( request->body );
    db->submit( $uuid, 'programme', 'anon', $data );
    return { status => 'OK' };
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
