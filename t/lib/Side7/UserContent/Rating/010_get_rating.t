use strict;
use warnings;

use Test::More tests => 8;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent::Rating';

# Attempt to get a Rating object.

my $RATING_ID = 1; # Image-related rating, 'E', Priority 1, requires_qualifier 0.
my $BAD_RATING_ID = 1234567890;

my $rating = Side7::UserContent::Rating->new( id => $RATING_ID );
my $loaded = $rating->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Rating object from database.' );

isa_ok( $rating, 'Side7::UserContent::Rating', 'User Content Rating object' );

is( $rating->rating(), 'E', 'Pulled proper Rating name.' );

is( $rating->requires_qualifier(), '0', 'Pulled proper Rating requires_qualifier.' );

is( $rating->priority(), 1, 'Pulled proper Rating priority.' );

my $no_rating = Side7::UserContent::Rating->new( id => $BAD_RATING_ID );
$loaded = $no_rating->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid User Content Rating object from database.' );
