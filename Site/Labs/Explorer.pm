package Lintilla::Site::Labs::Explorer;

use Dancer ':syntax';

=head1 NAME

Lintilla::Site::Labs::Explorer - Schedule explorer

=cut

our $VERSION = '0.1';

prefix '/labs' => sub {

  get '/explorer' => sub {
    template 'labs/explorer',
     {title   => 'Genome Schedule Explorer',
      scripts => ['explorer'],
      css     => ['explorer'],
     },
     { layout => 'labs2' };
  };

};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
