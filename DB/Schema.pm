package Lintilla::DB::Schema;

use Moose;

=head1 NAME

Lintilla::DB::Schema - Database schema

=cut

sub schema {
  return {
    stash => {
      pkey  => "id",
      table => "genome_stash",
      root  => 1
    },
    comments => {
      root  => 1,
      table => "genome_comments",
      pkey  => "_uuid"
    },
    unstem => {
      pkey  => "stem",
      root  => 1,
      table => "genome_unstem"
    },
    uuid_map => {
      pkey     => "id",
      child_of => {
        overrides     => "uuid",
        infax         => "uuid",
        programmes_v2 => "uuid",
        sources       => "uuid",
        services      => "uuid"
      },
      table => "genome_uuid_map",
      root  => 1
    },
    listings_v2 => {
      root     => 1,
      table    => "genome_listings_v2",
      child_of => {
        services => "service",
        sources  => "source",
        issues   => "issue"
      },
      pkey => "_uuid"
    },
    service_dates => {
      table    => "genome_service_dates",
      child_of => { services => "service" },
      pkey     => ["service", "date"]
    },
    data_counter      => { table => "genome_data_counter" },
    media_spreadsheet => {
      root  => 1,
      table => "genome_media_spreadsheet",
      pkey  => "id"
    },
    regions => {
      root  => 1,
      table => "genome_regions",
      pkey  => "_uuid"
    },
    services => {
      table    => "genome_services",
      root     => 1,
      pkey     => "_uuid",
      child_of => { services => "_parent" }
    },
    sources => {
      root  => 1,
      table => "genome_sources",
      pkey  => "_uuid"
    },
    overrides => {
      child_of => { programmes_v2 => "_uuid" },
      pkey     => "_uuid",
      root     => 1,
      table    => "genome_overrides"
    },
    changelog => {
      pkey     => "id",
      child_of => {
        infax         => "uuid",
        programmes_v2 => "uuid"
      },
      table => "genome_changelog",
      root  => 1
    },
    variation_items => { table => "genome_variation_items" },
    debug           => {
      table => "genome_debug",
      root  => 1,
      pkey  => "name"
    },
    edit => {
      pkey     => "id",
      child_of => {
        infax         => "uuid",
        programmes_v2 => "uuid"
      },
      table => "genome_edit",
      root  => 1
    },
    edit_digest => {
      root     => 1,
      table    => "genome_edit_digest",
      child_of => {
        infax         => "uuid",
        programmes_v2 => "uuid"
      },
      pkey => "id"
    },
    service_aliases => {
      table    => "genome_service_aliases",
      child_of => { services => "_parent" }
    },
    tables => {
      child_of => {
        programmes_v2 => "_parent",
        issues        => "issue",
        infax         => "_parent"
      },
      table => "genome_tables"
    },
    related => {
      root     => 1,
      table    => "genome_related",
      child_of => {
        programmes_v2 => "_parent",
        issues        => "issue",
        infax         => "_parent",
        listings_v2   => "_parent"
      },
      pkey => "_uuid"
    },
    sequence => {
      pkey  => "kind",
      table => "genome_sequence",
      root  => 1
    },
    region_aliases => {
      child_of => { regions => "_parent" },
      table    => "genome_region_aliases"
    },
    comment_tags => {
      pkey  => ["_comment_uuid", "_tag_uuid"],
      table => "genome_comment_tags"
    },
    media_collection => {
      pkey  => "id",
      table => "genome_media_collection",
      root  => 1
    },
    programmes_v2 => {
      root     => 1,
      table    => "genome_programmes_v2",
      child_of => {
        listings_v2   => "listing",
        services      => "service",
        sources       => "source",
        programmes_v2 => "_parent",
        issues        => "issue",
        overrides     => "_uuid",
        infax         => "_uuid"
      },
      pkey => "_uuid"
    },
    coordinates => {
      table    => "genome_coordinates",
      child_of => {
        overrides     => "_parent",
        infax         => "_parent",
        issues        => "issue",
        programmes_v2 => "_parent",
        related       => "_parent"
      }
    },
    listing_notes => {
      child_of => { services => "service" },
      table    => "genome_listing_notes"
    },
    editlog => {
      table => "genome_editlog",
      root  => 1,
      pkey  => "id"
    },
    tags => {
      pkey  => "_uuid",
      table => "genome_tags",
      root  => 1
    },
    variations => {
      root  => 1,
      table => "genome_variations",
      pkey  => "_uuid"
    },
    content_messages => {
      table => "genome_content_messages",
      root  => 1,
      pkey  => "id"
    },
    infax => {
      table    => "genome_infax",
      root     => 1,
      pkey     => "uuid",
      child_of => { programmes_v2 => "uuid" }
    },
    config => { table => "genome_config" },
    issues => {
      root     => 1,
      table    => "genome_issues",
      child_of => { issues => "_parent" },
      pkey     => "_uuid"
    },
    editstats => {
      pkey  => ["slot", "state"],
      table => "genome_editstats"
    },
    edit_comment => {
      pkey  => "id",
      root  => 1,
      table => "genome_edit_comment"
    },
    media => {
      child_of => {
        programmes_v2 => "_parent",
        infax         => "_parent"
      },
      table => "genome_media"
    },
    contributors => {
      child_of => {
        programmes_v2 => "_parent",
        infax         => "_parent"
      },
      table => "genome_contributors"
    } };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
