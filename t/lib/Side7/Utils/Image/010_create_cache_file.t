use strict;
use warnings;

use Test::More tests => 10;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::File';
use_ok 'Side7::Utils::Image';
use_ok 'Side7::UserContent::Image';

# Attempt to create a cache file for an image.

my $SIZE                 = 'medium';
my $EXPECTED_PATH        = '/galleries/2/2/2/side7work.jpg';      # Image # 4362
my $EXPECTED_CACHED_PATH = '/data/cached_files/user_content/images/medium/2/2/2/4362.jpg'; # Cached file path

# Fetch an image.  Using BadKarma's image "Side 7 - Hard at work" ID: 4362
my $image = Side7::UserContent::Image->new( id => 4362 );
my $loaded = $image->load( speculative => 1 );

isnt( $loaded, 0, 'Image loaded from DB' );

SKIP:
{
    skip "Image not loaded from DB", 5 if $loaded == 0;

    my ( $cached_file_path, $error, $success ) = ( undef, undef, undef );

    ( $cached_file_path, $error ) = $image->get_cached_image_path( size => $SIZE );
    is( $error, undef, 'Generated cached image path' );

    SKIP:
    {
        skip "Cache file doesn't already exist, no need to delete", 1 if ! -f $cached_file_path;

        is( unlink( $cached_file_path ), 1, 'Successfully removed existent cached file' ) ||
            diag( 'Could not remove cached file: ' . $! );
    } 

    is( $cached_file_path, $EXPECTED_CACHED_PATH, 'Generated cached file path is correct' );

    ( $success, $error ) = Side7::Utils::Image::create_cached_image( image => $image, size => $SIZE, path => $cached_file_path );

    is( $success, 1, 'Created cached image file' ) ||
        diag( 'Create cached file failed: ' . $error );

    is( -f $cached_file_path, 1, 'Cached file creation verified' );
}
