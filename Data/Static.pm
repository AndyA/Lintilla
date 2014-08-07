package Lintilla::Data::Static;

use Moose;
use JSON;
use Path::Class;

=head1 NAME

Lintilla::Data::Static - Static JSON backed data

=cut

has store => ( is => 'ro', required => 1 );
has _stash => ( is => 'ro', default => sub { {} }, required => 1 );

sub get {
  my ( $self, $key ) = @_;
  return $self->_load_file($key)->{data};
}

sub inject {
  my ( $self, %kv ) = @_;
  while ( my ( $key, $value ) = each %kv ) {
    die "Bad key" unless $key =~ /^\w+$/;
    $self->_stash->{$key} = { data => $value };
  }
  $self;
}

sub _load_file {
  my ( $self, $key ) = @_;
  my $stash = $self->_stash;
  # Injectecd?
  return $stash->{$key}
   if $stash->{$key} && !exists $stash->{$key}{mtime};
  my $file  = $self->_file_for_key($key);
  my $mtime = $file->stat->mtime;
  return $stash->{$key}
   if $stash->{$key} && $stash->{$key}{mtime} == $mtime;
  return $stash->{$key} = {
    mtime => $mtime,
    data  => $self->_load_json($file),
  };
}

sub _load_json {
  my ( $self, $file ) = @_;
  return JSON->new->utf8->decode( scalar $file->slurp );
}

sub _file_for_key {
  my ( $self, $key ) = @_;
  die "Bad key" unless $key =~ /^\w+$/;
  return file $self->store, "$key.json";
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
