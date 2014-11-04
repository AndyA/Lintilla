package Lintilla::DB::Genome::Edit;

use v5.10;

use Moose;
use Dancer qw( :syntax );

use Carp qw( confess );
use Lintilla::Versions::ChangeLog;
use Storable qw( freeze );
use Text::DeepDiff;
use Text::HTMLCleaner;
use Time::HiRes qw( time );

=head1 NAME

Lintilla::DB::Genome::Edit - Editing support

=cut

our $VERSION = '0.1';

with 'Lintilla::Role::DB';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::DataHash';
with 'Lintilla::Role::DataCounter';

use constant SYNC_PAGE  => 100;
use constant SYNC_EDITS => 10;

sub unique(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

sub audit {
  my ( $self, $edit_id, $who, $kind, $old_state, $new_state, $old_data,
    $new_data )
   = @_;
  my ($log_id);
  $self->transaction(
    sub {
      $self->dbh->do(
        join( ' ',
          'INSERT INTO genome_editlog',
          '  (`edit_id`, `who`, `old_state`, `new_state`, `old_data`, `new_data`, `when`, `data_hash`)',
          '  VALUES (?, ?, ?, ?, ?, ?, NOW(), ?)' ),
        {},
        $edit_id, $who,
        $old_state,
        $new_state,
        $old_data,
        $new_data,
        $self->data_hash( $old_state, $new_state, $old_data, $new_data )
      );
      $log_id = $self->dbh->last_insert_id( undef, undef, undef, undef );
      $self->bump( 'edit', $kind,
        [unique( grep { defined } $old_state, $new_state )] );
    }
  );
  return $log_id;
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

sub _clean_html {
  my ( $self, $html ) = @_;
  return $self->_clean_lines(
    Text::HTMLCleaner->new( html => $html )->text );
}

sub _diff {
  my ( $self, $text, $html ) = @_;

  my $left = $self->_clean_lines( $text // '' );
  my $right = defined $html ? $self->_clean_html($html) : $left;

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
    push @rows, join ': ', ( $rec->{type} // 'Unknown' ), join ' ',
     grep defined, $rec->{first_name}, $rec->{last_name};
  }

  return join "\n", @rows;
}

sub edit_history {
  my ( $self, $id ) = @_;

  my $hist
   = $self->dbh->selectall_arrayref(
    'SELECT * FROM genome_editlog WHERE edit_id=? ORDER BY `when`',
    { Slice => {} }, $id );
  my @list = ();

  for my $ev (@$hist) {
    my @desc = ();

    if ( ( $ev->{old_state} // '' ) ne $ev->{new_state} ) {
      push @desc, join ' ', 'state changed',
       ( defined $ev->{old_state} ? ( 'from', uc $ev->{old_state} ) : () ),
       'to', uc $ev->{new_state};
    }

    push @desc, 'edited'
     if ( $ev->{old_data} // '' ) ne ( $ev->{new_data} // '' );

    delete @{$ev}{ 'old_data', 'new_data' };
    push @list, { %$ev, description => join( ', ', @desc ), };
  }
  return \@list;
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

  my $data = $self->_decode_wide( delete $edit->{data} );
  $edit->{contributors} = $self->_contrib( $edit->{uuid} );

  return {
    edit    => $edit,
    data    => $data,
    link    => $self->strip_uuid( $edit->{uuid} ),
    history => $self->edit_history($id),
    ( map { $_ => $self->_diff( $edit->{$_}, $data->{$_} ) }
       qw( title synopsis contributors )
    ),
  };
}

sub change_count {
  my $self = shift;
  my ($count)
   = $self->dbh->selectrow_array('SELECT COUNT(*) FROM genome_changelog');
  return $count;
}

sub edit_state_count {
  my $self     = shift;
  my $by_state = $self->group_by(
    $self->dbh->selectall_arrayref(
      'SELECT `state`, COUNT(*) AS `count` FROM genome_edit GROUP BY `state`',
      { Slice => {} }
    ),
    'state'
  );
  return { map { $_ => $by_state->{$_}[0]{count} } keys %$by_state };
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
        'SELECT e.`id`, e.`uuid`, e.`kind`, e.`state`, e.`data`, p.`title`,',
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
    $rc->{data} = $self->_decode_wide( $rc->{data} );
  }

  return $self->group_by( $res, @group ) if @group;

  return $res;
}

sub _submit {
  my ( $self, $uuid, $kind, $who, $data, $state, $parent, $hash ) = @_;
  my $dbh = $self->dbh;
  $self->transaction(
    sub {
      my ($got)
       = $dbh->selectrow_array(
        'SELECT COUNT(hash) FROM genome_edit WHERE hash=?',
        {}, $hash );
      return if $got;
      my $new_data = $self->_encode($data);
      $dbh->do(
        join( ' ',
          'INSERT INTO genome_edit',
          '(`parent_id`, `uuid`, `kind`, `data`, `state`, `hash`, `data_hash`)',
          'VALUES (?, ?, ?, ?, ?, ?, ?)' ),
        {},
        $parent,
        $self->format_uuid($uuid),
        $kind,
        $new_data,
        $state, $hash,
        $self->data_hash( $state, $new_data )
      );
      my $edit_id = $dbh->last_insert_id( undef, undef, undef, undef );
      $self->audit( $edit_id, $who, $kind, undef, 'pending', undef,
        $new_data );
    }
  );
}

sub submit {
  my ( $self, $uuid, $kind, $who, $data, $state, $parent ) = @_;
  $state //= 'pending';

  my $hash = $self->data_hash(
    { uuid   => $uuid,
      kind   => $kind,
      who    => $who,
      data   => $data,
      state  => $state,
      parent => $parent,
      now    => time,
    }
  );

  return $self->_submit( $uuid, $kind, $who, $data, $state, $parent,
    $hash );
}

sub import_edits {
  my ( $self, $batch ) = @_;
  for my $edit ( @{ $batch->{edits} } ) {
    # Only allow new, pending edits
    next if defined $edit->{old_state};
    next unless defined $edit->{new_state};
    next unless $edit->{new_state} eq 'pending';

    $self->_submit(
      @{$edit}{ 'uuid', 'kind', 'who', 'new_data', 'new_state' },
      undef, $edit->{hash} );
  }
}

sub decode_data {
  my ( $self, $hash ) = @_;

  return [map { $self->decode_data($_) } @$hash]
   if 'ARRAY' eq ref $hash;

  my $out = {};
  for my $key ( keys %$hash ) {
    $out->{$key}
     = $key =~ /^(?:\w+_)?data$/
     ? defined $hash->{$key}
       ? $self->_decode_wide( $hash->{$key} )
       : undef
     : $hash->{$key};
  }
  return $out;
}

sub load_edit {
  my ( $self, $edit_id ) = @_;
  my $edit
   = $self->dbh->selectrow_hashref( 'SELECT * FROM genome_edit WHERE id=?',
    {}, $edit_id );
  die "Edit not found" unless defined $edit;
  $edit->{data} = $self->_decode_wide( $edit->{data} );
  return $edit;
}

# Munge editlog into suitable shape for Lintilla::Versions::ChangeLog
sub _normalise_editlog {
  my ( $self, $log ) = @_;

  my @out = ();
  for my $ev (@$log) {
    push @out,
     {old_data => {
        state => $ev->{old_state},
        data  => $self->_decode_wide( $ev->{old_data} )
      },
      new_data => {
        state => $ev->{new_state},
        data  => $self->_decode_wide( $ev->{new_data} )
      },
     };
  }

  return \@out;
}

sub _normalised_editlog {
  my ( $self, $edit_id ) = @_;
  return $self->_normalise_editlog(
    $self->dbh->selectall_arrayref(
      'SELECT * FROM genome_editlog WHERE edit_id=? ORDER BY id ASC',
      { Slice => {} }, $edit_id
    )
  );
}

# Get an instance of an edit in its initial state. That's actually
# state #1 because there's a state change for their creation and
# semantically #0 is pre-natal
sub _stem_edit {
  my ( $self, $id ) = @_;

  my $edit = $self->decode_data(
    $self->dbh->selectrow_hashref(
      'SELECT * FROM genome_edit WHERE id=?',
      {}, $id
    )
  );

  confess "Edit $id not found" unless defined $edit;

  my $el  = $self->_normalised_editlog($id);
  my $ver = Lintilla::Versions::ChangeLog->new(
    data => $edit,
    log  => $el
  );

  return $ver->at(1);
}

sub load_edit_history {
  my ( $self, $since, $limit ) = @_;
  my $editlog = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT el.*, e.hash',
      'FROM genome_editlog AS el, genome_edit AS e',
      'WHERE el.edit_id=e.id',
      'AND el.id > ?',
      'ORDER BY el.id ASC LIMIT ?' ),
    { Slice => {} },
    $since,
    $limit // SYNC_PAGE
  );

  return { sequence => $since, editlog => [] }
   unless $editlog && @$editlog;

  $self->decode_data($editlog);

  for my $ev (@$editlog) {
    if ( !defined $ev->{old_state} ) {
      $ev->{edit} = $self->_stem_edit( $ev->{edit_id} );
    }
  }
  return { sequence => $editlog->[-1]{id}, editlog => $editlog };
}

sub load_edits {
  my ( $self, $since ) = @_;
  my $edits = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT el.*, e.parent_id, e.uuid, e.kind, e.hash',
      'FROM genome_editlog AS el, genome_edit AS e',
      'WHERE el.edit_id=e.id',
      "AND e.alien='N'",
      'AND el.id > ?',
      'ORDER BY el.id',
      'LIMIT ?' ),
    { Slice => {} },
    $since,
    SYNC_EDITS
  );
  return { sequence => $since, edits => [] }
   unless $edits && @$edits;
  for my $key ( 'old_data', 'new_data' ) {
    for my $ch (@$edits) {
      $ch->{$key} = $self->_decode_wide( $ch->{$key} );
      $ch->{$key}{type} //= 'html' if defined $ch->{$key};
    }
  }
  return { sequence => $edits->[-1]{id}, edits => $edits };
}

sub load_changes {
  my ( $self, $since ) = @_;
  my $changes = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT cl.*, e.hash',
      'FROM genome_changelog AS cl, genome_edit AS e',
      'WHERE cl.id > ?',
      'AND cl.edit_id=e.id',
      'ORDER BY cl.id ASC',
      'LIMIT ?' ),
    { Slice => {} },
    $since,
    SYNC_PAGE
  );
  return { sequence => $since, changes => [] }
   unless $changes && @$changes;
  for my $key ( 'old_data', 'new_data' ) {
    $_->{$key} = $self->_decode_wide( $_->{$key} ) for @$changes;
  }
  return { sequence => $changes->[-1]{id}, changes => $changes };
}

sub amend {
  my ( $self, $edit_id, $who, $state, $data ) = @_;
  my ($editlog_id);
  $self->transaction(
    sub {
      my $old = $self->load_edit($edit_id);

      # Default: unchanged
      $data  //= $old->{data};
      $state //= $old->{state};

      my $old_data = $self->_encode( $old->{data} );
      my $new_data = $self->_encode($data);

      return if $state eq $old->{state} && $old_data eq $new_data;

      $self->dbh->do( 'UPDATE genome_edit SET state=?, data=? WHERE id=?',
        {}, $state, $new_data, $edit_id );

      $editlog_id
       = $self->audit( $edit_id, $who, $old->{kind}, $old->{state}, $state,
        $old_data, $new_data );
    }
  );
  return $editlog_id;
}

sub workflow {
  my ( $self, $edit_id, $who, $action ) = @_;

  my %ST = (
    accepted => 'accepted',
    pending  => 'pending',
    rejected => 'rejected',
    review   => 'review',
  );

  my $status = { status => 'OK' };

  $self->transaction(
    sub {
      my $new_state = $ST{$action} // die "Bad action: $action";

      my $old
       = $self->dbh->selectrow_hashref( 'SELECT * FROM genome_edit WHERE id=?',
        {}, $edit_id );
      die "Edit not found" unless defined $old;

      my @msg = (
        join ' ', 'Moved from', uc( $old->{state} ),
        'to', uc($new_state) . '.'
      );

      my $editlog_id = $self->amend( $edit_id, $who, $new_state, undef );
      unless ($editlog_id) {
        @msg = ('Nothing to do.');
      }

      # The only transitions that affect data are to and from accepted.
      if ( $new_state eq 'accepted' && $old->{state} ne 'accepted' ) {
        $self->do_edit( [$edit_id, $editlog_id], $who );
        push @msg, 'Edit applied to live site.';
      }
      elsif ( $new_state ne 'accepted' && $old->{state} eq 'accepted' ) {
        $self->undo_edit($edit_id);
        push @msg, 'Edit rolled back on live site.';
      }

      $status->{message} = join ' ', @msg;
    }
  );

  return $status;
}

sub list_stash {
  my $self = shift;
  my $st
   = $self->dbh->selectall_arrayref(
    'SELECT * FROM genome_stash ORDER BY name',
    { Slice => {} } );

  for my $rec (@$st) {
    $rec->{stash} = $self->_decode_wide( $rec->{stash} );
  }

  return $st;
}

sub _parse_contributor_line {
  my ( $self, $ln ) = @_;
  return ( $1, $2 ) if $ln =~ m{^\s*([^:]+):\s*(.+?)\s*$};
  return ( $1, $2 ) if $ln =~ m{^\s*(\S+)\s*(.+)$};    # handle Title Name
  return ( 'Unknown', $ln );
}

sub _parse_contributors {
  my ( $self, $contrib ) = @_;
  return $contrib if ref $contrib;
  my $idx = 0;
  my @row = ();
  for my $ln ( split /\n/, $contrib ) {
    next if $ln =~ m{^\s*$};
    my ( $type, $name ) = $self->_parse_contributor_line($ln);
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

sub _strip_contrib {
  my ( $self, $data ) = @_;
  for my $row (@$data) {
    %$row = map { $_ => $row->{$_} } qw( first_name last_name type );
  }
  return $data;
}

sub strip_thing {
  my ( $self, $kind, $thing ) = @_;
  die unless $kind eq 'programme';
  $self->_strip_contrib( $thing->{contributors} )
   if exists $thing->{contributors};
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
      if (@$data) {
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

  sub load_thing {
    my ( $self, $kind, $uuid ) = @_;
    my $kh = $KIND{$kind} // die;
    return $kh->{get}( $self, $uuid );
  }

  sub save_thing {
    my ( $self, $kind, $uuid, $data, $edit_id ) = @_;
    my $kh = $KIND{$kind} // die;
    return $kh->{put}( $self, $uuid, $data, $edit_id );
  }

  sub _unpack_id {
    my ( $self, $id ) = @_;
    return @$id if ref $id;
    return ( $id, undef );
  }

  sub _apply {
    my ( $self, $kind, $uuid, $who, $data, $eid, $bump, $hash ) = @_;
    my ( $edit_id, $editlog_id ) = $self->_unpack_id($eid);

    my ($next_id);
    my $new_data = {%$data};

    $self->transaction(
      sub {
        my $kh = $KIND{$kind} // die;

        my $old_data = $kh->{get}( $self, $uuid );
        my ( $old_modified, $old_edit_id )
         = delete @{$old_data}{ '_modified', '_edit_id' };
        delete @{$new_data}{ '_modified', '_edit_id' };

        # Only stash data that changes
        for my $ok ( keys %$old_data ) {
          delete $old_data->{$ok} unless exists $new_data->{$ok};
          if ( $self->_deep_cmp( $old_data->{$ok}, $new_data->{$ok} ) ) {
            delete $old_data->{$ok};
            delete $new_data->{$ok};
          }
        }

        # It'd probably be bad (for sync) to change the way this
        # hash is computed.
        my $data_hash = $self->data_hash( $old_data, $new_data );

        # Update if necessary
        if ( keys %$new_data ) {
          $self->dbh->do(
            join( ' ',
              'INSERT INTO genome_changelog',
              '(`edit_id`, `editlog_id`, `prev_id`, `uuid`, `kind`, `who`, `created`, `old_data`, `new_data`, `data_hash`)',
              'VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?)' ),
            {},
            $edit_id,
            $editlog_id,
            $old_edit_id,
            $self->format_uuid($uuid),
            $kind, $who,
            $self->_encode($old_data),
            $self->_encode($new_data),
            $data_hash,
          );
          $next_id = $self->dbh->last_insert_id( undef, undef, undef, undef );
        }

        # Always update programme on undo - to change _edit_id
        if ( defined $next_id || $bump eq 'undo' ) {
          my $new_edit_id = $next_id;
          if ( $bump eq 'undo' ) {
            ($new_edit_id)
             = $self->dbh->selectrow_array(
              'SELECT prev_id FROM genome_changelog WHERE id=?',
              {}, $old_edit_id );
          }
          $kh->{put}( $self, $uuid, $new_data, $new_edit_id );
          $self->bump( 'change', $kind, $bump );
        }
      }
    );
    return $next_id;
  }

  sub _undo_edit {
    my ( $self, $id ) = @_;
    $self->transaction(
      sub {
        my $change
         = $self->dbh->selectrow_hashref(
          'SELECT * FROM genome_changelog WHERE id=?',
          {}, $id );
        die unless $change;

        # TODO should also roll back the associated edits
        $self->_apply(
          @{$change}{ 'kind', 'uuid', 'who' },
          $self->_decode_wide( $change->{old_data} ),
          [$change->{edit_id}, $change->{editlog_id}], 'undo'
        );
      }
    );
  }
}

sub apply {
  my $self = shift;
  return $self->_apply( @_, 'apply' );
}

sub _undo {
  my ( $self, $id, $safe ) = @_;
  $self->transaction(
    sub {
      my ($uuid)
       = $self->dbh->selectrow_array(
        'SELECT uuid FROM genome_changelog WHERE id=?',
        {}, $id );
      return unless defined $uuid;
      my $hist = $self->history( $uuid, $id );
      shift @$hist while @$hist && $hist->[0]{id} != $id;
      # Only safe if this edit is the most recent
      die "Can't undo edit" if $safe && @$hist > 1;
      while (@$hist) {
        my $ch = pop @$hist;
        $self->_undo_edit( $ch->{id} );
      }
    }
  );
}

# Currently unused
sub undo {
  my ( $self, $id ) = @_;
  $self->_undo( $id, 0 );
}

sub safe_undo {
  my ( $self, $id ) = @_;
  $self->_undo( $id, 1 );
}

sub history {
  my ( $self, $uuid, $stopat ) = @_;
  my ($next)
   = $self->dbh->selectrow_array(
    'SELECT _edit_id FROM genome_programmes_v2 WHERE _uuid=?',
    {}, $uuid );
  my @hist = ();
  while ( defined $next ) {
    my $ev
     = $self->dbh->selectrow_hashref(
      'SELECT * FROM genome_changelog WHERE id=?',
      {}, $next );
    push @hist, $ev;
    last if defined $stopat && $stopat == $next;
    $next = $ev->{prev_id};
  }
  return \@hist;
}

sub _parse_edit {
  my ( $self, $edit ) = @_;
  my $rec = {};
  $rec->{title} = $self->_clean_html( $edit->{title} )
   if defined $edit->{title};
  $rec->{synopsis} = $self->_clean_html( $edit->{synopsis} )
   if defined $edit->{synopsis};
  $rec->{contributors}
   = $self->_parse_contributors(
    $self->_clean_html( $edit->{contributors} ) )
   if defined $edit->{contributors};
  return $rec;
}

sub do_edit {
  my ( $self, $txn_id, $who ) = @_;
  my ( $edit_id, $editlog_id ) = @$txn_id;
  $self->transaction(
    sub {
      my $edit = $self->load_edit($edit_id);
      $self->apply( 'programme', $edit->{uuid}, $who,
        $self->_parse_edit( $edit->{data} ), $txn_id );
    }
  );
}

sub undo_edit {
  my ( $self, $edit_id ) = @_;
  $self->transaction(
    sub {
      my ($id) = $self->dbh->selectrow_array(
        join( ' ',
          'SELECT id',
          'FROM genome_changelog',
          'WHERE edit_id=?',
          'ORDER BY id DESC',
          'LIMIT 1' ),
        {},
        $edit_id
      );
      die "Unknown edit ID" unless defined $id;
      $self->safe_undo($id);
    }
  );
}

sub get_sequence {
  my ( $self, $kind ) = @_;
  my ($seq)
   = $self->dbh->selectrow_array(
    'SELECT hwm FROM genome_sequence WHERE kind=?',
    {}, $kind );
  return $seq // 0;
}

sub set_sequence {
  my ( $self, $kind, $hwm ) = @_;
  $self->dbh->do(
    join( ' ',
      'INSERT INTO genome_sequence ( kind, hwm ) VALUES (?, ?)',
      'ON DUPLICATE KEY UPDATE hwm=?' ),
    {},
    $kind, $hwm, $hwm
  );
}

sub apply_batch {
  my ( $self, $batch ) = @_;
  my $next_seq = $batch->{sequence} // die "Missing sequence in batch";
  $self->transaction(
    sub {
      for my $ch ( @{ $batch->{changes} } ) {
        $self->apply( @{$ch}{ 'kind', 'uuid', 'who', 'new_data', 'edit_id' } );
      }
      $self->set_sequence( 'changelog', $next_seq );
    }
  );
}

# Sync V2

sub _create_edit {
  my ( $self, $edit ) = @_;
  $self->dbh->do(
    join( ' ',
      'INSERT INTO genome_edit (hash, parent_id, uuid, kind, data, state, alien, data_hash)',
      "VALUES (?, ?, ?, ?, ?, ?, 'Y', ?)" ),
    {},
    $edit->{hash},
    $edit->{parent_id},
    $edit->{uuid},
    $edit->{kind},
    $self->_encode( $edit->{data} ),
    $edit->{state},
    $self->data_hash( $edit->{state}, $edit->{data} )
  );
  return $self->dbh->last_insert_id( undef, undef, undef, undef );
}

sub _edit_for_event {
  my ( $self, $ev ) = @_;
  my $by_hash
   = $self->dbh->selectrow_hashref(
    'SELECT id FROM genome_edit WHERE hash=?',
    {}, $ev->{hash} );
  return $by_hash->{id} if defined $by_hash;
  die unless exists $ev->{edit};
  return $self->_create_edit( $ev->{edit} );
}

sub _import_edit {
  my ( $self, $ev ) = @_;

  my $edit_id = $self->_edit_for_event($ev);

  my $editlog_id
   = $self->amend( $edit_id, $ev->{who}, $ev->{new_state},
    $ev->{new_data} );

  print "edit_id: $edit_id, editlog_id: $editlog_id\n";

  if ( $ev->{new_state} eq 'accepted'
    && ( $ev->{old_state} // '' ) ne 'accepted' ) {
    $self->do_edit( [$edit_id, $editlog_id], $ev->{who} );
  }
  elsif ( $ev->{new_state} ne 'accepted'
    && ( $ev->{old_state} // '' ) eq 'accepted' ) {
    $self->undo_edit($edit_id);
  }

}

sub import_history {
  my ( $self, $history ) = @_;
  my $next_seq = $history->{sequence} // die "Missing sequence in history";
  $self->transaction(
    sub {
      for my $edit ( @{ $history->{editlog} } ) {
        $self->_import_edit($edit);
      }
      $self->set_sequence( 'edit_history', $next_seq );
    }
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
