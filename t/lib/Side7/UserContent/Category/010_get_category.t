use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent::Category';

# Attempt to get a Category object.

my $CATEGORY_ID = 1; # Image-related category, 'Furry / Anthropomorphic', Priority 15.
my $BAD_CATEGORY_ID = 1234567890;

my $category = Side7::UserContent::Category->new( id => $CATEGORY_ID );
my $loaded = $category->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Category object from database.' );

isa_ok( $category, 'Side7::UserContent::Category', 'User Content Category object' );

is( $category->category(), 'Furry / Anthropomorphic', 'Pulled proper Category name.' );

is( $category->priority(), 15, 'Pulled proper Category priority.' );

my $no_category = Side7::UserContent::Category->new( id => $BAD_CATEGORY_ID );
$loaded = $no_category->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid User Content Category object from database.' );
