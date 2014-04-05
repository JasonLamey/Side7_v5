use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User::Type';

# Attempt to get a Type object.

my $TYPE_ID = 2; # Premiere
my $BAD_TYPE_ID = 1234567890;

my $type = Side7::User::Type->new( id => $TYPE_ID );
my $loaded = $type->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Type object from database.' );

isa_ok( $type, 'Side7::User::Type', 'User Type object' );

is( $type->user_type(), 'Premiere', 'Pulled proper Type name.' );

my $no_type = Side7::User::Type->new( id => $BAD_TYPE_ID );
$loaded = $no_type->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid User Type object from database.' );
