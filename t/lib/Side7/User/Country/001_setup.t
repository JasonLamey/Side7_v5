use strict;
use warnings;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Test::More tests => 2;

use_ok('Side7');
use_ok('Side7::User::Country');
