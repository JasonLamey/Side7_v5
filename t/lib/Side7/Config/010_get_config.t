use strict;
use warnings;

use Test::More tests => 4;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Config';

# Attempt to get the Config.

my $CONFIG = Side7::Config::new();

is( ref($CONFIG), 'HASH', 'Config object is a hash.' );

is( $CONFIG->{'general'}->{'version'}, '5.0', 'Can get $CONFIG values.' );
