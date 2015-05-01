#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer ':script';
use Dancer::Plugin::Database;
use Lintilla::Data::Model;

use constant WORKFLOW_UNCHECKED => 'RES Unchecked';
use constant WORKFLOW_APPROVED  => 'RES Suitable';

my $model = Lintilla::Data::Model->new( dbh => database );

my $unch_id = $model->make_tag(WORKFLOW_UNCHECKED);
my $appr_id = $model->make_tag(WORKFLOW_APPROVED);

database->do(
  join( ' ',
    'INSERT INTO elvis_image_keyword (acno, id)',
    '  SELECT i.acno, ? FROM elvis_image AS i',
    '    JOIN elvis_image_keyword AS ik1 ON ik1.acno=i.acno AND ik1.id=?',
    '    LEFT JOIN elvis_image_keyword AS ik2 ON ik2.acno=i.acno AND ik2.id=?',
    '    WHERE ik2.id IS NULL' ),
  {},
  $unch_id, $appr_id, $unch_id
);

# vim:ts=2:sw=2:sts=2:et:ft=perl
