package Lintilla::Site::Labs::Schedule;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Labs::Factory;
use Lintilla::Magic::Asset;
use Path::Class;

=head1 NAME

Lintilla::Site::Labs::Schedule - Dynamic schedule chunks

=cut

our $VERSION = '0.1';

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

prefix '/labs' => sub {

  # Dynamic schedule chunks
  prefix '/var/schedule' => sub {
    my @base_path = ( 'labs', 'var', 'schedule' );

    get '/range' => sub {
      my @path = ( @base_path, 'range' );
      my $out_file = file setting('public'), @path;

      my $magic = Lintilla::Magic::Asset->new(
        filename => $out_file,
        timeout  => 20,
        provider => Labs::Factory->schedule_model( out_file => $out_file ),
        method   => 'create_range'
      );

      $magic->render or die "Can't render";
      my $self = our_uri_for(@path) . '?1';
      return redirect $self, 307;
    };

    get '/week/:slot' => sub {
      my $slot = param('slot');
      die "Bad slot" unless $slot =~ /^\d+$/;
      my @path = ( @base_path, 'week', $slot );
      my $out_file = file setting('public'), @path;

      my $magic = Lintilla::Magic::Asset->new(
        filename => $out_file,
        timeout  => 20,
        provider => Labs::Factory->schedule_model(
          slot     => $slot,
          out_file => $out_file,
        ),
        method => 'create_week'
      );

      $magic->render or die "Can't render";
      my $self = our_uri_for(@path) . '?1';
      return redirect $self, 307;
    };
  };

};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
