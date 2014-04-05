use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent::Image';

# Attempt to get an Image object.

my $IMAGE_ID = 336287; # BadKarma's image: Principles of Animation Class: Bouncing Ball.
my $BAD_IMAGE_ID = 1234567890;

my $image = Side7::UserContent::Image->new( id => $IMAGE_ID );
my $loaded = $image->load( speculative => 1, with => [ 'user', 'rating', 'category', 'stage' ] );

isnt( $loaded, 0, 'Loaded Image object from database.' );

isa_ok( $image, 'Side7::UserContent::Image', 'Image object' );

is( $image->title(), 'Principles of Animation Class: Bouncing Ball', 'Pulled proper Image title.' );

my $username = $image->user->username();

is( $username, 'BadKarma', 'Can get User data from Image object.' );

my $no_image = Side7::UserContent::Image->new( id => $BAD_IMAGE_ID );
$loaded = $image->load( speculative => 1, with => [ 'user', 'rating', 'category', 'stage' ] );

isnt( $loaded, 0, 'Did not load invalid Image object from database.' );
