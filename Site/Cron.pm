package Lintilla::Site::Cron;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Genome::Factory;

=head1 NAME

Lintilla::Site::Cron - Run cron jobs

=cut

get "/cron" => sub { Genome::Factory->cron->run };

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
