package Lintilla::Sync::ErrorLog;

use Moose;

use JSON ();
use List::Util qw( max );
use Scalar::Util qw( looks_like_number );

=head1 NAME

Lintilla::Sync::ErrorLog - Log errors

=cut

1;

has _errors => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has _stats  => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

has _level => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

my @LVL_NUM_TO_NAME = qw( DEBUG NOTE WARN ERROR FATAL);
my %LVL_NAME_TO_NUM
 = map { $LVL_NUM_TO_NAME[$_] => $_ } 0 .. $#LVL_NUM_TO_NAME;
my $MAX_LVL = max map length, @LVL_NUM_TO_NAME;

{
  for my $level (@LVL_NUM_TO_NAME) {
    no strict 'refs';
    *{ lc $level } = sub { shift->_report( $level, @_ ) };
  }
}

sub level {
  my $self = shift;
  return $self->_level unless @_;
  return $self->_level( $self->_level_num(@_) );
}

sub _path_as_array {
  my $self = shift;
  map { 'ARRAY' eq ref $_ ? $self->_path_as_array(@$_) : split /\./ } @_;
}

sub _put {
  my ( $self, $value, $h, $key, @path ) = @_;
  return $self->_put( $value, $h->{$key} //= {}, @path ) if @path;
  push @{ $h->{$key} }, $value;
}

sub _level_num {
  my ( $self, $name ) = @_;
  if ( looks_like_number $name) {
    confess "Bad level number: $name"
     if $name < 0 || $name >= @LVL_NUM_TO_NAME;
    return $name;
  }
  return $LVL_NAME_TO_NUM{ uc $name } // confess "Bad level name: $name";
}

sub _level_name {
  my ( $self, $num ) = @_;
  return $LVL_NUM_TO_NAME[$self->_level_num($num)];
}

sub _pretty {
  my ( $self, $val ) = @_;
  return $val if defined $val && !ref $val;
  return JSON->new->canonical->allow_nonref->encode($val);
}

sub _add {
  my ( $self, $path, $thing, $msg ) = @_;
  $self->_stats->{ $msg->{level} }++;
  $self->_put( $msg, $self->_errors, @$path, $thing );
  return $self;
}

sub _report {
  my ( $self, $level, $path, $thing, @msg ) = @_;
  my $nlevel = $self->_level_num($level);
  return if $nlevel < $self->level;
  my @ln = split /\n/, join '', map { $self->_pretty($_) } @msg;
  my @path = $self->_path_as_array($path);
  return $self->_add(
    \@path,
    $thing,
    { level      => $nlevel,
      level_name => $self->_level_name($nlevel),
      message    => \@ln,
      type       => 'message',
    }
  );
}

sub got {
  my ( $self, $level ) = @_;
  return $self->_stats->{ $self->_level_num($level) } // 0;
}

sub at_least {
  my ( $self, $level ) = @_;
  my $total = 0;
  for my $ln ( $self->_level_num($level) .. $#LVL_NUM_TO_NAME ) {
    $total += $self->got($ln);
  }
  return $total;
}

sub _traverse {
  my ( $self, $h, @path ) = @_;
  return $h unless @path;
  my $key = shift @path;
  return $self->_traverse( $h->{$key}, @path ) if exists $h->{$key};
  return;
}

sub report {
  my ( $self, @path ) = @_;
  return $self->_traverse( $self->_errors, $self->_path_as_array(@path) );
}

sub _smart_sort {
  my ( $self, @v ) = @_;
  my @nn = grep { !looks_like_number $_ } @v;
  return sort { $a cmp $b } @v if @nn;
  return sort { $a <=> $b } @v;
}

sub _make_iter {
  my ( $self, $obj ) = @_;

  confess "Not a referernce" unless ref $obj;

  if ( 'ARRAY' eq ref $obj ) {
    my @queue = @$obj;
    return sub { shift @queue };
  }

  if ( 'HASH' eq ref $obj ) {
    my @keys = $self->_smart_sort( keys %$obj );
    return sub {
      return unless @keys;
      my $key = shift @keys;
      return {
        type     => 'section',
        name     => $key,
        iterator => $self->_make_iter( $obj->{$key} ) };
    };
  }
}

sub iterator {
  my $self = shift;
  return $self->_make_iter( $self->report(@_) );
}

sub _format_iter {
  my ( $self, $iter, $depth ) = @_;
  $depth //= 0;
  my $pad = '  ' x $depth;
  my @ln  = ();
  while ( my $itm = $iter->() ) {
    if ( $itm->{type} eq 'section' ) {
      push @ln,
       "$pad$itm->{name}",
       $self->_format_iter( $itm->{iterator}, $depth + 1 );
    }
    elsif ( $itm->{type} eq 'message' ) {
      my $tag = $itm->{level_name};
      for my $ln ( @{ $itm->{message} } ) {
        push @ln, sprintf "%s%-${MAX_LVL}s %s", $pad, $tag, $ln;
        $tag = '';
      }
    }
  }
  return @ln;
}

sub as_string {
  my $self = shift;
  join "\n", $self->_format_iter( $self->iterator(@_) ), "\n";
}

sub _visit {
  my ( $self, $ds, $cb, @path ) = @_;

  confess "Not a ref" unless ref $ds;

  if ( 'HASH' eq ref $ds ) {
    while ( my ( $k, $v ) = each %$ds ) {
      $self->_visit( $v, $cb, @path, $k );
    }
    return;
  }

  if ( 'ARRAY' eq ref $ds ) {
    my $thing = pop @path;
    for my $msg (@$ds) {
      $cb->( \@path, $thing, $msg );
    }
    return;
  }

  confess "Not a HASH or ARRAY";

}

sub visit {
  my ( $self, @path ) = @_;
  my $cb = pop @path;
  return $self->_visit( $self->report(@path), $cb, @path );
}

sub _mk_prefixer {
  my ( $self, @pfx ) = @_;
  return sub { $_[0] }
   unless @pfx;
  my @pre = $self->_path_as_array(@pfx);
  return sub { [@pre, @{ $_[0] }] };
}

sub merge {
  my ( $self, @other ) = @_;

  my @pfx = ();
  push @pfx, shift @other
   while @other && !ref $other[0] || 'ARRAY' eq ref $other[0];

  my $pxr = $self->_mk_prefixer(@pfx);

  for my $el (@other) {
    $el->visit(
      sub {
        my ( $path, $thing, $msg ) = @_;
        $self->_add( $pxr->($path), $thing, $msg );
      }
    );
  }

  return $self;
}

sub status_line {
  my $self = shift;
  join ', ', map { join ': ', $_, $self->got($_) } @LVL_NUM_TO_NAME;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
