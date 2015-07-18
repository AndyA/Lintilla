package Lintilla::DB::Genome::Labs::WordFrequency;

use Moose;

=head1 NAME

Lintilla::DB::Genome::Labs::WordFrequency - Use word frequency data

=cut

with 'Lintilla::Role::DB';

use constant FLUSH_THRESHOLD => 10_000;

has max_frequency => (
  is      => "ro",
  isa     => "Num",
  lazy    => 1,
  builder => "_b_max_frequency"
);

has _pending_words => (
  is      => "rw",
  isa     => "ArrayRef",
  default => sub { [] }
);

sub _b_max_frequency {
  my $self = shift;
  my ($most)
   = $self->dbh->selectrow_array(
    "SELECT MAX(`frequency`) FROM `labs_word_frequency`");
  return $most // 0;
}

sub find_words {
  my $self  = shift;
  my $text  = join " ", @_;
  my @words = $text =~ /([a-z]{3,40})/gi;
  return @words;
}

sub word_frequency {
  my ( $self, @text ) = @_;

  my @words      = $self->find_words(@text);
  my %word_count = map { $_ => 0 } @words;
  my @bind       = sort keys %word_count;

  my $freq = $self->dbh->selectall_arrayref(
    join( " ",
      "SELECT * FROM `labs_word_frequency` WHERE `word` IN (",
      join( ", ", map "?", @bind ), ")" ),
    { Slice => {} },
    @bind
  );

  $word_count{ $_->{word} } = $_->{frequency} for @$freq;

  return \%word_count;
}

sub word_rarity {
  my ( $self, @text ) = @_;
  my $word_count    = $self->word_frequency(@text);
  my $max_frequency = $self->max_frequency;
  $_ /= $max_frequency for values %$word_count;
  return $word_count;
}

sub flush {
  my $self = shift;
  my $bind = $self->_pending_words;
  return unless @$bind;

  $self->_pending_words( [] );

  $self->dbh->do(
    join( " ",
      "INSERT INTO `labs_word_frequency` (`word`) VALUES",
      join( ", ", map "(?)", @$bind ),
      "ON DUPLICATE KEY UPDATE `frequency` = `frequency` + 1" ),
    {},
    @$bind
  );
}

sub clear {
  shift->dbh->do("TRUNCATE `labs_word_frequency`");
}

sub add_text {
  my ( $self, @text ) = @_;
  my @words = $self->find_words(@text);
  while (@words) {
    push @{ $self->_pending_words }, splice @words, 0, FLUSH_THRESHOLD / 10;
    $self->flush if @{ $self->_pending_words } >= FLUSH_THRESHOLD;
  }
}

1;
