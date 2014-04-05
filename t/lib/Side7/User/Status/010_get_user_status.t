use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User::Status';

# Attempt to get a Status object.

my $STATUS_ID = 2; # Active
my $BAD_STATUS_ID = 1234567890;

my $status = Side7::User::Status->new( id => $STATUS_ID );
my $loaded = $status->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Status object from database.' );

isa_ok( $status, 'Side7::User::Status', 'User Status object' );

is( $status->user_status(), 'Active', 'Pulled proper Status name.' );

my $no_status = Side7::User::Status->new( id => $BAD_STATUS_ID );
$loaded = $no_status->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid User Status object from database.' );
