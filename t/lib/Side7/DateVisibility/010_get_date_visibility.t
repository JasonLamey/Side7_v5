use strict;
use warnings;

use Test::More tests => 12;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::DateVisibility';

# Attempt to get date visibility.

my $FULL_ID      = 1;
my $HIDE_YEAR_ID = 2;
my $HIDDEN_ID    = 3;
my $INVALID_ID   = 10;

# Full ID returns full date.
my $date_visibility = Side7::DateVisibility->new( id => $FULL_ID );
my $loaded = $date_visibility->load( speculative => 1 );

isnt( $loaded, 0, 'Visibility loaded.' );
isa_ok( $date_visibility, 'Side7::DateVisibility' );
is( $date_visibility->visibility(), 'Full', 'Full ID returned proper visibility' );

# Hide Year ID returns hide year date.
$date_visibility = Side7::DateVisibility->new( id => $HIDE_YEAR_ID );
$loaded = $date_visibility->load( speculative => 1 );

isnt( $loaded, 0, 'Visibility loaded.' );
isa_ok( $date_visibility, 'Side7::DateVisibility' );
is( $date_visibility->visibility(), 'Hide Year', 'Hide Year ID returned proper visibility' );

# Hidden ID returns a hidden date.
$date_visibility = Side7::DateVisibility->new( id => $HIDDEN_ID );
$loaded = $date_visibility->load( speculative => 1 );

isnt( $loaded, 0, 'Visibility loaded.' );
isa_ok( $date_visibility, 'Side7::DateVisibility' );
is( $date_visibility->visibility(), 'Hidden', 'Hidden ID returned proper visibility' );

# Invalid ID returns nothing.
$date_visibility = Side7::DateVisibility->new( id => $INVALID_ID );
$loaded = $date_visibility->load( speculative => 1 );

is( $loaded, 0, 'Invalid ID did not load anything.' );
