package Lintilla::Sync::ErrorLog;

use Moose;

use List::Util qw( max );
use Scalar::Util qw( looks_like_number );

=head1 NAME

Lintilla::Sync::ErrorLog - Log errors

=cut

1;

has _errors => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has _stats  => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

my @LVL_NUM_TO_NAME = qw( FATAL ERROR WARN NOTE DEBUG );
my %LVL_NAME_TO_NUM
 = map { $LVL_NUM_TO_NAME[$_] => $_ } 0 .. $#LVL_NUM_TO_NAME;
my $MAX_LVL = max map length, @LVL_NUM_TO_NAME;

{
  for my $level (@LVL_NUM_TO_NAME) {
    no strict 'refs';
    *{ lc $level } = sub { shift->_report( $level, @_ ) };
  }
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

sub _report {
  my ( $self, $level, $path, $thing, @msg ) = @_;
  my @ln = split /\n/, join '', @msg;
  my @p = ( $self->_path_as_array($path), $thing );
  my $nlevel = $self->_level_num($level);

  $self->_stats->{$nlevel}++;

  $self->_put(
    { level      => $nlevel,
      level_name => $self->_level_name($nlevel),
      message    => \@ln,
      type       => 'message',
    },
    $self->_errors,
    @p
  );
  return $self;
}

sub got {
  my ( $self, $level ) = @_;
  return $self->_stats->{ $self->_level_num($level) } // 0;
}

sub at_least {
  my ( $self, $level ) = @_;
  my $total = 0;
  for my $ln ( 0 .. $self->_level_num($level) ) {
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

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
