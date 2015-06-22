package Lintilla::DB::Schema;

use Moose;

=head1 NAME

Lintilla::DB::Schema - Database schema

=cut

sub schema {
  return {
    changelog => {
      child_of => {
        infax         => "uuid",
        programmes_v2 => "uuid"
      },
      pkey  => "id",
      root  => 1,
      table => "genome_changelog"
    },
    comment_tags => {
      pkey  => ["_comment_uuid", "_tag_uuid"],
      table => "genome_comment_tags"
    },
    comments => {
      pkey  => "_uuid",
      root  => 1,
      table => "genome_comments"
    },
    config           => { table => "genome_config" },
    content_messages => {
      pkey  => "id",
      root  => 1,
      table => "genome_content_messages"
    },
    contributors => {
      child_of => {
        infax         => "_parent",
        programmes_v2 => "_parent"
      },
      table => "genome_contributors"
    },
    coordinates => {
      child_of => {
        infax         => "_parent",
        issues        => "issue",
        overrides     => "_parent",
        programmes_v2 => "_parent",
        related       => "_parent"
      },
      table => "genome_coordinates"
    },
    data_counter => { table => "genome_data_counter" },
    debug        => {
      pkey  => "name",
      root  => 1,
      table => "genome_debug"
    },
    edit => {
      child_of => {
        infax         => "uuid",
        programmes_v2 => "uuid"
      },
      pkey  => "id",
      root  => 1,
      table => "genome_edit"
    },
    edit_comment => {
      pkey  => "id",
      root  => 1,
      table => "genome_edit_comment"
    },
    edit_digest => {
      child_of => {
        infax         => "uuid",
        programmes_v2 => "uuid"
      },
      pkey  => "id",
      root  => 1,
      table => "genome_edit_digest"
    },
    editlog => {
      pkey  => "id",
      root  => 1,
      table => "genome_editlog"
    },
    editstats => {
      pkey  => ["slot", "state"],
      table => "genome_editstats"
    },
    infax => {
      child_of => { programmes_v2 => "uuid" },
      pkey     => "uuid",
      root     => 1,
      table    => "genome_infax"
    },
    issues => {
      child_of => { issues => "_parent" },
      pkey     => "_uuid",
      root     => 1,
      table    => "genome_issues"
    },
    listing_notes => {
      child_of => { services => "service" },
      table    => "genome_listing_notes"
    },
    listings_v2 => {
      child_of => {
        issues   => "issue",
        services => "service",
        sources  => "source"
      },
      pkey  => "_uuid",
      root  => 1,
      table => "genome_listings_v2"
    },
    media => {
      child_of => {
        infax         => "_parent",
        programmes_v2 => "_parent"
      },
      table => "genome_media"
    },
    media_collection => {
      pkey  => "id",
      root  => 1,
      table => "genome_media_collection"
    },
    media_spreadsheet => {
      pkey  => "id",
      root  => 1,
      table => "genome_media_spreadsheet"
    },
    overrides => {
      child_of => { programmes_v2 => "_uuid" },
      pkey     => "_uuid",
      root     => 1,
      table    => "genome_overrides"
    },
    programmes_v2 => {
      child_of => {
        infax         => "_uuid",
        issues        => "issue",
        listings_v2   => "listing",
        overrides     => "_uuid",
        programmes_v2 => "_parent",
        services      => "service",
        sources       => "source"
      },
      pkey  => "_uuid",
      root  => 1,
      table => "genome_programmes_v2"
    },
    region_aliases => {
      child_of => { regions => "_parent" },
      table    => "genome_region_aliases"
    },
    regions => {
      pkey  => "_uuid",
      root  => 1,
      table => "genome_regions"
    },
    related => {
      child_of => {
        infax         => "_parent",
        issues        => "issue",
        listings_v2   => "_parent",
        programmes_v2 => "_parent"
      },
      pkey  => "_uuid",
      root  => 1,
      table => "genome_related"
    },
    sequence => {
      pkey  => "kind",
      root  => 1,
      table => "genome_sequence"
    },
    service_aliases => {
      child_of => { services => "_parent" },
      table    => "genome_service_aliases"
    },
    service_dates => {
      child_of => { services => "service" },
      pkey  => ["service", "date"],
      table => "genome_service_dates"
    },
    services => {
      child_of => { services => "_parent" },
      pkey     => "_uuid",
      root     => 1,
      table    => "genome_services"
    },
    sources => {
      pkey  => "_uuid",
      root  => 1,
      table => "genome_sources"
    },
    stash => {
      pkey  => "id",
      root  => 1,
      table => "genome_stash"
    },
    tables => {
      child_of => {
        infax         => "_parent",
        issues        => "issue",
        programmes_v2 => "_parent"
      },
      table => "genome_tables"
    },
    tags => {
      pkey  => "_uuid",
      root  => 1,
      table => "genome_tags"
    },
    unstem => {
      pkey  => "stem",
      root  => 1,
      table => "genome_unstem"
    },
    uuid_map => {
      child_of => {
        infax         => "uuid",
        overrides     => "uuid",
        programmes_v2 => "uuid",
        services      => "uuid",
        sources       => "uuid"
      },
      pkey  => "id",
      root  => 1,
      table => "genome_uuid_map"
    },
    variation_items => { table => "genome_variation_items" },
    variations      => {
      pkey  => "_uuid",
      root  => 1,
      table => "genome_variations"
    } };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
