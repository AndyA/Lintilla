#!perl

use strict;
use warnings;

use Data::Dumper;
use Test::More;

use Lintilla::DB::Genome;
{
  my $db = Lintilla::DB::Genome->new;
  ok $db, 'created';

  {
    my $input = [
      { type => 'radio', title => 'Radio 1', },
      { type => 'tv',    title => 'BBC 4', },
      { type => 'radio', title => 'Radio 4', },
      { type => 'tv',    title => 'BBC 1', },
      { type => 'radio', title => 'Radio 3', },
      { type => 'tv',    title => 'BBC 2', },
      { type => 'radio', title => 'Radio 2', },
      { type => 'tv',    title => 'BBC 3', },
    ];

    my $output = {
      radio => [
        { title => 'Radio 1', },
        { title => 'Radio 4', },
        { title => 'Radio 3', },
        { title => 'Radio 2', },
      ],
      tv => [
        { title => 'BBC 4', },
        { title => 'BBC 1', },
        { title => 'BBC 2', },
        { title => 'BBC 3', },
      ],
    };

    my $got = $db->_group_by( $input, 'type' );
    is_deeply $got, $output, 'group by' or diag Dumper($got);
  }

  {
    my $input = [
      { A => 'a', B => 'one', C => 'left',  V => 'a-one-left-1' },
      { A => 'b', B => 'one', C => 'left',  V => 'b-one-left-1' },
      { A => 'a', B => 'two', C => 'left',  V => 'a-two-left-1' },
      { A => 'b', B => 'two', C => 'left',  V => 'b-two-left-1' },
      { A => 'a', B => 'one', C => 'right', V => 'a-one-right-1' },
      { A => 'b', B => 'one', C => 'right', V => 'b-one-right-1' },
      { A => 'a', B => 'two', C => 'right', V => 'a-two-right-1' },
      { A => 'b', B => 'two', C => 'right', V => 'b-two-right-1' },
      { A => 'a', B => 'one', C => 'left',  V => 'a-one-left-2' },
      { A => 'b', B => 'one', C => 'left',  V => 'b-one-left-2' },
      { A => 'a', B => 'two', C => 'left',  V => 'a-two-left-2' },
      { A => 'b', B => 'two', C => 'left',  V => 'b-two-left-2' },
      { A => 'a', B => 'one', C => 'right', V => 'a-one-right-2' },
      { A => 'b', B => 'one', C => 'right', V => 'b-one-right-2' },
      { A => 'a', B => 'two', C => 'right', V => 'a-two-right-2' },
      { A => 'b', B => 'two', C => 'right', V => 'b-two-right-2' },
    ];

    my $output = {
      'a' => {
        'one' => {
          'left'  => [{ 'V' => 'a-one-left-1' },  { 'V' => 'a-one-left-2' }],
          'right' => [{ 'V' => 'a-one-right-1' }, { 'V' => 'a-one-right-2' }]
        },
        'two' => {
          'left'  => [{ 'V' => 'a-two-left-1' },  { 'V' => 'a-two-left-2' }],
          'right' => [{ 'V' => 'a-two-right-1' }, { 'V' => 'a-two-right-2' }] }
      },
      'b' => {
        'one' => {
          'left'  => [{ 'V' => 'b-one-left-1' },  { 'V' => 'b-one-left-2' }],
          'right' => [{ 'V' => 'b-one-right-1' }, { 'V' => 'b-one-right-2' }]
        },
        'two' => {
          'left'  => [{ 'V' => 'b-two-left-1' },  { 'V' => 'b-two-left-2' }],
          'right' => [{ 'V' => 'b-two-right-1' }, { 'V' => 'b-two-right-2' }] } }
    };

    my $got = $db->_group_by( $input, 'A', 'B', 'C' );
    is_deeply $got, $output, 'group by (nested)' or diag Dumper($got);
  }

}

done_testing;

# vim:ts=2:sw=2:et:ft=perl

