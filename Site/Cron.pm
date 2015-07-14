package Lintilla::Site::Cron;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Lintilla::DB::Genome::Cron;

=head1 NAME

Lintilla::Site::Cron - Run cron jobs

=cut

get "/cron" => sub {
  my $cron = Lintilla::DB::Genome::Cron->new( dbh => database );
  return $cron->run;
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
