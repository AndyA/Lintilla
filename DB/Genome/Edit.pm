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
  my ( $self, $uuid, $kind, $who, $data, $state, $parent ) = @_;
  my $dbh = $self->dbh;
  $state //= 'pending';
  $self->transaction(
    sub {
      $dbh->do(
        'INSERT INTO genome_edit (`parent`, `uuid`, `kind`, `data`, `state`) VALUES (?, ?, ?, ?, ?)',
        {},
        $parent,
        $self->format_uuid($uuid),
        $kind,
        JSON->new->utf8->allow_nonref->encode($data),
        $state
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

sub _format_contributors {
  my ( $self, $contrib ) = @_;
}

sub _parse_contributors {
  my ( $self, $contrib ) = @_;
  return $contrib if ref $contrib;
  my $idx = 0;
  my @row = ();
  for my $ln ( split /\n/, $contrib ) {
    next if $ln =~ m{^\s*$};
    die unless $ln =~ m{^\s*([^:]+):\s*(.+?)\s*$};
    my ( $type, $name ) = ( $1, $2 );
    $type = undef if $type eq 'Unknown';
    my @np    = split /\s+/, $name;
    my $last  = pop @np;
    my $first = @np ? join( ' ', @np ) : undef;
    push @row,
     {type       => $type,
      first_name => $first,
      last_name  => $last
     };
  }
  return \@row;
}

sub _default_contrib {
  my ( $self, $data ) = @_;
  my $idx = 0;
  for my $row (@$data) {
    %$row = (
      index => $idx,
      group => 'crew',
      kind  => 'member',
      code  => undef,
      %$row
    );
    $idx = $row->{index} + 1;
  }
  return $data;
}

sub _put_contrib {
  my ( $self, $uuid, $contrib ) = @_;
  $self->transaction(
    sub {
      my $data
       = $self->_default_contrib( $self->_parse_contributors($contrib) );
      my $fuuid = $self->format_uuid($uuid);
      $self->dbh->do( 'DELETE FROM genome_contributors WHERE _parent=?',
        {}, $fuuid );
      my %kk = ();
      %kk = ( %kk, %$_ ) for @$data;
      delete $kk{_parent};    # override
      my @f = sort keys %kk;
      my $val = join ', ', ('?') x @f;
      $self->dbh->do(
        join( ' ',
          'INSERT INTO genome_contributors',
          '(',
          join( ', ', map { "`$_`" } '_parent', @f ),
          ') VALUES',
          join( ', ', map { "( ?, $val )" } @$data ) ),
        {},
        map { $fuuid, @{$_}{@f} } @$data
      );
    }
  );
}

sub _put_programme {
  my ( $self, $uuid, $data, $edit_id ) = @_;

  $self->transaction(
    sub {
      $self->_put_contrib( $uuid, delete $data->{contributors} )
       if exists $data->{contributors};

      my @f = sort keys %$data;

      if (@f) {
        my @b = @{$data}{@f};

        $self->dbh->do(
          join( ' ',
            'UPDATE', "`genome_programmes_v2`", 'SET',
            join( ', ', '`_modified`=NOW()', map { "`$_`=?" } '_edit_id', @f ),
            'WHERE _uuid=? LIMIT 1' ),
          {},
          $edit_id, @b, $uuid
        );
      }

    }
  );
}

sub _get_contrib {
  my ( $self, $uuid ) = @_;
  return $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT *',
      'FROM genome_contributors',
      'WHERE _parent=?',
      'ORDER BY `index`' ),
    { Slice => {} },
    $self->format_uuid($uuid)
  );
}

sub _get_programme {
  my ( $self, $uuid ) = @_;
  my $fuuid = $self->format_uuid($uuid);
  my $prog  = $self->dbh->selectrow_hashref(
    'SELECT `_modified`, `_edit_id`, `title`, `synopsis` FROM `genome_programmes_v2` WHERE `_uuid`=?',
    {}, $fuuid
  );
  $prog->{contributors} = $self->_get_contrib($fuuid);
  return $prog;
}

sub _deep_cmp {
  my ( $self, $a, $b ) = @_;

  return 1 unless defined $a || defined $b;
  return unless defined $a && defined $b;
  return $a eq $b unless ref $a || ref $b;
  return unless ref $a && ref $b && ref $a eq ref $b;

  if ( ref $a eq 'ARRAY' ) {
    return unless @$a == @$b;
    for my $i ( 0 .. $#$a ) {
      return unless $self->_deep_cmp( $a->[$i], $b->[$i] );
    }
    return 1;
  }

  if ( ref $a eq 'HASH' ) {
    my %kk = map { $_ => 1 } keys %$a;
    $kk{$_}++ for keys %$b;
    for my $k ( grep { $kk{$_} == 2 } keys %$b ) {
      return unless $self->_deep_cmp( $a->{$k}, $b->{$k} );
    }
    return 1;
  }

  return;
}

{
  my %KIND = (
    programme => {
      put => sub { shift->_put_programme(@_) },
      get => sub { shift->_get_programme(@_) }
    }
  );

  sub apply {
    my ( $self, $kind, $uuid, $who, $data, $edit_id ) = @_;

    my ($next_id);
    $self->transaction(
      sub {
        my $kh = $KIND{$kind} // die;

        my $old_data = $kh->{get}( $self, $uuid );
        my ( $old_modified, $old_edit_id )
         = delete @{$old_data}{ '_modified', '_edit_id' };

        # Only stash data that changes
        for my $ok ( keys %$old_data ) {
          delete $old_data->{$ok} unless exists $data->{$ok};
          if ( $self->_deep_cmp( $old_data->{$ok}, $data->{$ok} ) ) {
            delete $old_data->{$ok};
            delete $data->{$ok};
          }
        }

        # Update if necessary
        if ( keys %$data ) {
          $self->dbh->do(
            join( ' ',
              'INSERT INTO genome_changelog',
              '(`edit_id`, `prev_id`, `uuid`, `kind`, `who`, `created`, `old_data`, `new_data`)',
              'VALUES (?, ?, ?, ?, ?, NOW(), ?, ?)' ),
            {},
            $edit_id,
            $old_edit_id,
            $self->format_uuid($uuid),
            $kind, $who,
            JSON->new->allow_nonref->utf8->encode($old_data),
            JSON->new->allow_nonref->utf8->encode($data)
          );
          $next_id = $self->dbh->last_insert_id( undef, undef, undef, undef );
          $kh->{put}( $self, $uuid, $data, $next_id );
        }
      }
    );
    return $next_id;
  }

  sub undo {
    my ( $self, $id ) = @_;
    $self->transaction(
      sub {
        my $edit
         = $self->dbh->selectrow_hashref(
          'SELECT * FROM genome_changelog WHERE id=?',
          {}, $id );
        die unless $edit;

        my $kh = $KIND{ $edit->{kind} } // die;

        $kh->{put}(
          $self, $edit->{uuid},
          JSON->new->allow_nonref->utf8->decode( $edit->{old_data} ),
          $edit->{prev_id}
        );

        $self->dbh->do( 'DELETE FROM genome_changelog WHERE id=?', {}, $id );
      }
    );
  }
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
