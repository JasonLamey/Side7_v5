use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent::Image::Property';

# Attempt to get an Image Property object.

my $IMAGE_ID = 336287; # BadKarma's image: Principles of Animation Class: Bouncing Ball.
my $BAD_IMAGE_ID = 1234567890;

my $image_property = Side7::UserContent::Image::Property->new( image_id => $IMAGE_ID, name => 'Allow Comments' );
my $loaded = $image_property->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Image Property object from database.' );

isa_ok( $image_property, 'Side7::UserContent::Image::Property', 'Image Property object' );

is( $image_property->name(), 'Allow Comments', 'Pulled proper Image Property name.' );

is( $image_property->value(), 'True', 'Pulled proper Image Property value.' );

my $no_image_property = Side7::UserContent::Image::Property->new( image_id => $BAD_IMAGE_ID, name => 'Allow Comments' );
$loaded = $no_image_property->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid Image Property object from database.' );
