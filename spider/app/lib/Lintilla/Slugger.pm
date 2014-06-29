package Lintilla::Slugger;

use Moose;

use List::Util qw( min max );

=head1 NAME

Lintilla::Slugger - Text slugger

=cut

has text  => ( is => 'ro', required => 1 );
has query => ( is => 'ro', required => 1 );

sub iterator {
  my $self = shift;
  return mk_presenter( $self->text, 'hit',
    mk_merger( phrase_slugs( $self->text, $self->query, 40, 60 ) ) );
}

sub mk_presenter {
  my ( $text, $class, $iter ) = @_;
  return sub {
    my $slug = $iter->();
    return unless $slug;
    my ( $from, $to, @pos ) = @$slug;
    my @out = ();
    my $lp  = $from;
    for my $pos (@pos) {
      ( my $frag = substr $text, $lp, $pos - $lp )
       =~ s/(\w+)$/<span class="$class">$1<\/span>/;
      push @out, $frag;
      $lp = $pos;
    }
    push @out, substr $text, $lp, $to - $lp;
    return join '', @out;
  };
}

sub mk_merger {
  my $iter = shift;
  my $next = $iter->();
  return sub {
    return unless $next;
    my $prev = $next;
    while () {
      $next = $iter->();
      last unless $next;
      last if $next->[0] > $prev->[1];
      $prev->[1] = $next->[1];
      push @$prev, @{$next}[2 .. $#$next];
    }
    return $prev;
  };
}

sub phrase_slugs {
  my ( $text, $phrase, $before, $after ) = @_;
  my @wslug = ();
  for my $word ( split_words($phrase) ) {
    push @wslug,
     [word_slugs( $text, $before, $after, word_pos( $word, $text ) )];
  }

  return sub {
    @wslug = sort { $a->[0][0] <=> $b->[0][0] } grep { scalar @$_ } @wslug;
    return unless @wslug;
    my $slug = shift @{ $wslug[0] };
    return $slug;
  };
}

sub split_words { split /\s+/, shift }

sub word_slugs {
  my ( $text, $before, $after, @pos ) = @_;
  my @slugs = ();
  for my $pos ( sort { $a <=> $b } @pos ) {
    my $from = max( 0, $pos - $before );
    my $to = min( $pos + $after, length $text );

    if ( @slugs && $from <= $slugs[-1][1] ) {
      $slugs[-1][1] = $to;
      push @{ $slugs[-1] }, $pos;
    }
    else {
      push @slugs, [$from, $to, $pos];
    }
  }
  return @slugs;
}

sub word_pos {
  my ( $word, $text ) = @_;
  my @pos = ();
  while ( $text =~ /\b\Q$word\E\b/smig ) {
    push @pos, 0 + pos($text);
  }
  return @pos;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
