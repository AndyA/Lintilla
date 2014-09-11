package Lintilla::DB::Genome::Edit;

use v5.10;

use Moose;

use JSON;
use Text::DeepDiff;
use Text::HTMLCleaner;

=head1 NAME

Lintilla::DB::Genome::Edit - Editing support

=cut

our $VERSION = '0.1';

with 'Lintilla::Role::DB';

sub audit {
  my $self = shift;
  my ( $edit_id, $who, $old_state, $new_state ) = @_;
  $self->dbh->do(
    join( ' ',
      'INSERT INTO genome_editlog',
      '  (`edit_id`, `who`, `old_state`, `new_state`, `when`)',
      '  VALUES (?, ?, ?, ?, NOW())' ),
    {},
    $edit_id, $who,
    $old_state,
    $new_state
  );
}

sub _cook_order {
  my $self = shift;
  my ($order) = @_;

  my %ok_order = map { $_ => 1 } qw(
   id uuid kind data state title service created updated
  );

  my @ord = ();
  for my $part ( split /,/, $order ) {
    my ( $dir, $fld )
     = $part =~ /^([-+])(.+)$/ ? ( $1, $2 ) : ( '+', $part );
    die unless $ok_order{$fld};
    push @ord, "`$fld` " . ( $dir eq '+' ? 'ASC' : 'DESC' );
  }
  return join ', ', @ord;
}

sub _cook_list {
  my $self = shift;
  my ($list) = @_;
  for my $itm (@$list) {
    #    $itm->{service} = join ' ', grep defined,
    #     @{$itm}{ 'ps_title', 'cs_title' };
  }
  return $list;
}

sub _clean_lines {
  my ( $self, $txt ) = @_;
  my @ln = split /\n/, $txt;
  s/^\s+//, s/\s+$//, s/\s+/ /g for @ln;
  my $out = join "\n", @ln;
  $out =~ s/\n\n\n+/\n\n/msg;
  return $out;
}

sub _diff {
  my ( $self, $text, $html ) = @_;

  my $left = $self->_clean_lines($text);
  my $right
   = $self->_clean_lines( Text::HTMLCleaner->new( html => $html )->text );

  my $diff = Text::DeepDiff->new( left => $left, right => $right )->diff;

  return {
    left  => $left,
    right => $right,
    diff  => $diff
  };
}

sub _contrib {
  my ( $self, $uuid ) = @_;

  my $contrib = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_contributors',
      'WHERE _parent=?',
      'ORDER BY `index`' ),
    { Slice => {} },
    $uuid
  );

  my @rows = ();
  for my $rec (@$contrib) {
    push @rows, join ': ', $rec->{type}, join ' ', $rec->{first_name},
     $rec->{last_name};
  }

  return join "\n", @rows;
}

sub diff {
  my ( $self, $id ) = @_;

  my $edit = $self->dbh->selectrow_hashref(
    join( ' ',
      'SELECT e.*, p.`title`, p.`synopsis`,',
      "  IF(s2.`title` IS NULL, s.`title`, CONCAT_WS(' ', s2.`title`, s.`title`)) AS service",
      'FROM genome_edit AS e, genome_programmes_v2 AS p, genome_services AS s',
      'LEFT JOIN genome_services AS s2 ON s2._uuid=s._parent',
      'WHERE e.uuid=p._uuid',
      '  AND s._uuid=p.service',
      '  AND e.id=?' ),
    undef, $id
  );

  my $data = JSON->new->decode( delete $edit->{data} );
  $edit->{contributors} = $self->_contrib( $edit->{uuid} );

  return {
    edit => $edit,
    data => $data,
    link => $self->strip_uuid( $edit->{uuid} ),
    ( map { $_ => $self->_diff( $edit->{$_}, $data->{$_} ) }
       qw( title synopsis contributors )
    ),
  };
}

sub list {
  my ( $self, $kind, $state, $start, $size, $order ) = @_;

  my $ord = $self->_cook_order($order);

  my @group = ();
  my @filt  = ();
  my @bind  = ();

  if ( $kind ne '*' ) { push @filt, 'AND e.kind=?'; push @bind, $kind }
  else                { push @group, 'kind' }

  if ( $state ne '*' ) { push @filt, 'AND e.state=?'; push @bind, $state }
  else                 { push @group, 'state' }

  my $res = $self->_cook_list(
    $self->dbh->selectall_arrayref(
      join( ' ',
        'SELECT e.`id`, e.`uuid`, e.`kind`, e.`state`,  p.`title`,',
        '  MIN(el.`when`) AS `created`, MAX(el.`when`) AS `updated`,',
        "  IF(s2.`title` IS NULL, s.`title`, CONCAT_WS(' ', s2.`title`, s.`title`)) AS service",
        'FROM genome_edit AS e, genome_editlog AS el, genome_programmes_v2 AS p, genome_services AS s',
        'LEFT JOIN genome_services AS s2 ON s2._uuid=s._parent',
        'WHERE e.uuid=p._uuid',
        @filt,
        '  AND e.id=el.edit_id',
        '  AND s._uuid=p.service',
        'GROUP BY id',
        "ORDER BY $ord",
        'LIMIT ?, ?' ),
      { Slice => {} },
      @bind, $start, $size
    )
  );

  for my $rc (@$res) {
    $rc->{link} = $self->strip_uuid( $rc->{uuid} );
  }

  return $self->group_by( $res, @group ) if @group;

  return $res;
}

sub submit {
  my ( $self, $uuid, $kind, $who, $data ) = @_;
  my $dbh = $self->dbh;
  $self->transaction(
    sub {
      $dbh->do(
        'INSERT INTO genome_edit (`uuid`, `kind`, `data`) VALUES (?, ?, ?)',
        {},
        $self->format_uuid($uuid),
        $kind,
        JSON->new->utf8->allow_nonref->encode($data)
      );
      my $edit_id = $dbh->last_insert_id( undef, undef, undef, undef );
      $self->audit( $edit_id, $who, undef, 'pending' );
    }
  );
}

sub list_stash {
  my $self = shift;
  my $st
   = $self->dbh->selectall_arrayref(
    'SELECT * FROM genome_stash ORDER BY name',
    { Slice => {} } );

  for my $rec (@$st) {
    $rec->{stash} = JSON->new->utf8->allow_nonref->decode( $rec->{stash} );
  }

  return $st;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
