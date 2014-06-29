#!perl

use strict;
use warnings;

use Test::More;

use Lintilla::Site;
use Dancer::Test;

route_exists [GET => '/'];
response_status_is ['GET' => '/'], 200;

route_exists [GET => '/schedules/bbctwo'];

done_testing;
