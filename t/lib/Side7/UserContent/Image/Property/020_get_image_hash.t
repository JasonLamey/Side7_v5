use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent::Image';

# Attempt to get a User Gallery that has content.

my $IMAGE_ID = 336287; # BadKarma's image: Principles of Animation Class: Bouncing Ball.
my $BAD_IMAGE_ID = 1234567890;

my $image_hash = Side7::UserContent::Image::show_image( image_id => $IMAGE_ID );

is( ref( $image_hash ), 'HASH', 'Image hash is a hash.' );

is( $image_hash->{'title'}, 'Principles of Animation Class: Bouncing Ball', 'Pulled proper Image title.' );

my $username = $image_hash->{'user'}->{'username'};

is( $username, 'BadKarma', 'Can get User data from Image object.' );

my $no_image = Side7::UserContent::Image::show_image( image_id => $BAD_IMAGE_ID );

is( $no_image, undef, 'Bad Image ID returned undef.' );
