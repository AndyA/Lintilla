package Lintilla::DB::Genome::Blog;

use v5.10;

use Moose;

use DateTime::Format::Mail;
use HTML::LinkExtor;
use LWP::UserAgent;
use Text::HTMLCleaner;
use URI;
use XML::LibXML::XPathContext;
use XML::LibXML;

our $VERSION = '0.1';

with 'Lintilla::Role::DB';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Config';
with 'Lintilla::Role::DateTime';
with 'Lintilla::Role::UUID';

=head1 NAME

Lintilla::DB::Genome::Blog - Fetch latest post from blog

=cut

sub _fetch {
  my ( $self, $uri ) = @_;
  my $ua   = LWP::UserAgent->new;
  my $resp = $ua->get($uri);
  die $resp->status_line if $resp->is_error;
  return $resp->content;
}

sub _decode_rss {
  my ( $self, $rss ) = @_;

  my $dom = XML::LibXML->load_xml( string => $rss );
  my $xp = XML::LibXML::XPathContext->new($dom);

  $xp->registerNs( atom    => "http://www.w3.org/2005/Atom" );
  $xp->registerNs( content => "http://purl.org/rss/1.0/modules/content/" );
  $xp->registerNs( dc      => "http://purl.org/dc/elements/1.1/" );
  $xp->registerNs( slash   => "http://purl.org/rss/1.0/modules/slash/" );

  my $pf = DateTime::Format::Mail->new();

  my @FIELDS = qw(
   comments content creator description guid link pubdate title
  );

  my %NAME_MAP = (
    "content:encoded" => "content",
    "dc:creator"      => "creator",
    "slash:comments"  => "comments",
    "pubDate"         => "pubdate"
  );

  my %FIELD_MAP = ( ( map { $_ => $_ } @FIELDS ), %NAME_MAP );

  my %VALUE_MAP = (
    pubdate => sub {
      my $dt = $pf->parse_datetime( $_[0] );
      return join " ", $dt->ymd, $dt->hms;
    }
  );

  my @items = ();

  for my $item ( $xp->findnodes("//item") ) {
    my $rec = {};
    for my $elt ( $item->findnodes("*") ) {
      my $name  = $elt->nodeName;
      my $text  = $elt->textContent;
      my $field = $FIELD_MAP{$name};
      next unless defined $field;
      my $value = ( $VALUE_MAP{$field} // sub { $_[0] } )->($text);
      $rec->{$field} = $value;
    }
    push @items, $rec;
  }
  return @items;
}

sub _find_links {
  my ( $self, $html ) = @_;
  my $ex = HTML::LinkExtor->new;
  $ex->parse($html);
  $ex->eof;
  my @out = ();
  for my $set ( $ex->links ) {
    my ( $tag, %links ) = @$set;
    push @out, values %links;
  }
  return @out;
}

sub _find_genome_links {
  my ( $self, @links ) = @_;

  # Fix broken links
  s|^(genome\.ch\.bbc\.co\.uk)|http://$1| for @links;

  my %seen = ();
  my @out  = ();
  for my $link (@links) {
    my $uri  = URI->new($link);
    my $path = $uri->path;
    next if $seen{$path}++;
    my @part = split /\//, $path;
    next
     unless @part == 2
     && $part[0] eq ""
     && $part[1] =~ /^[0-9a-f]{32}$/i;
    push @out, $self->format_uuid( $part[1] );
  }
  return @out;
}

sub _update_item {
  my ( $self, $item ) = @_;

  my @links = ();
  if ( defined $item->{content} ) {
    my $tc = Text::HTMLCleaner->new( html => $item->{content} );
    $item->{full_text} = $tc->text;
    push @links,
     $self->_find_genome_links( $self->_find_links( $item->{content} ) );
  }

  my ($id)
   = $self->dbh->selectrow_array(
    "SELECT `id` FROM `genome_blog_feed` WHERE `guid` = ?",
    {}, $item->{guid} );

  $item->{id} = $id if defined $id;

  my @cols = sort keys %$item;

  $self->dbh->do(
    join( " ",
      "REPLACE INTO `genome_blog_feed` (",
      join( ", ", map "`$_`", @cols ),
      ") VALUES (",
      join( ", ", map "?", @cols ),
      ")" ),
    {},
    @{$item}{@cols}
  );

  $id = $self->dbh->last_insert_id( undef, undef, undef, undef )
   unless defined $id;

  $self->dbh->do( "DELETE FROM `genome_blog_link` WHERE `blog_id` = ?",
    {}, $id );
  if (@links) {
    $self->dbh->do(
      join( " ",
        "INSERT INTO `genome_blog_link` (`blog_id`, `programme`) VALUES",
        join( ", ", map "(?, ?)", @links ) ),
      {},
      map { $id, $_ } @links
    );
  }
}

sub _update_blog {
  my ( $self, $name, $uri ) = @_;

  my $rss   = $self->_fetch($uri);
  my @items = $self->_decode_rss($rss);

  return unless @items;

  $self->transaction(
    sub {
      my ($version)
       = $self->dbh->selectrow_array(
        "SELECT MAX(`version`) + 1 FROM `genome_blog_feed` WHERE `blog` = ?",
        {}, $name );
      $version //= 1;

      for my $item (@items) {
        $item->{blog}    = $name;
        $item->{version} = $version;
        $self->_update_item($item);
      }
    }
  );
}

sub cron {
  my ( $self, $options ) = @_;
  $self->_update_blog( $options->{name}, $options->{feed} );
}

sub get_posts {
  my ( $self, $blog, @limit ) = @_;
  my $items = $self->dbh->selectall_arrayref(
    join( " ",
      "SELECT * FROM `genome_blog_feed`",
      "WHERE `blog` = ?",
      "ORDER BY `pubdate` DESC",
      ( @limit ? ("LIMIT ?") : () ) ),
    { Slice => {} },
    $blog, @limit
  ) // [];

  for my $item (@$items) {
    $item->{short_date}  = $self->short_date( $item->{pubdate} );
    $item->{pretty_date} = $self->pretty_date( $item->{pubdate} );
  }

  return $items;
}
