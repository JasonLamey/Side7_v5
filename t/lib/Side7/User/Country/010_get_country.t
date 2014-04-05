use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User::Country';

# Attempt to get a Country object.

my $COUNTRY_ID = 228; # USA
my $BAD_COUNTRY_ID = 1234567890;

my $country = Side7::User::Country->new( id => $COUNTRY_ID );
my $loaded = $country->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Country object from database.' );

isa_ok( $country, 'Side7::User::Country', 'User Country object' );

is( $country->name(), 'United States', 'Pulled proper Country name.' );

is( $country->code(), 'US', 'Pulled proper Country code.' );

my $no_country = Side7::User::Country->new( id => $BAD_COUNTRY_ID );
$loaded = $no_country->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid User Country object from database.' );
