package Lintilla::Magic::Asset;

use Moose;

use Dancer ':syntax';

use Fcntl qw( :flock );
use Lintilla::Util qw( wait_for_file );
use Path::Class;

=head1 NAME

Lintilla::Magic::Asset - A dynamic, cached asset

=cut

has filename => ( is => 'ro', required => 1 );
has provider => ( is => 'ro', required => 1 );

has timeout => ( isa => 'Maybe[Num]', is => 'ro', default => 20 );
has method  => ( isa => 'Str',        is => 'ro', default => 'create' );

sub render {
  my $self   = shift;
  my $fn     = $self->filename;
  my $method = $self->method;
  unless ( -e $fn ) {
    my $lockf = "$fn.LOCK";
    # TODO dump a .ERROR file if the conversion fails so we
    # don't get DOSed by repeatedly trying to convert a broken
    # file.
    # TODO move .LOCK / .ERROR into a parallel work dir - outside
    # webroot.
    file($lockf)->parent->mkpath;
    open my $lh, '>>', $lockf or die "Can't write $lockf: $!\n";
    if ( flock( $lh, LOCK_EX | LOCK_NB ) ) {
      eval { $self->provider->$method };
      my $err = $@;
      close $lh;
      die $err if $err;
    }
    else {
      # Wait
      flock( $lh, LOCK_EX );
    }
  }
  return unless -e $fn;
  return $fn;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
