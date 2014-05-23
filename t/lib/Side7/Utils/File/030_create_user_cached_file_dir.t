use strict;
use warnings;

use Test::More tests => 19;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Side7::Globals;

use_ok 'Side7';
use_ok 'Side7::Utils::File';

my $NEW_USER_ID      = 987543; # Non-existent User ID.
my $EXISTING_USER_ID = 2;      # BadKarma's User ID.
my $INVALID_USER_ID  = 'INVALID_ID_3'; # Erroneous User ID that shouldn't exist.

my $CONTENT_SIZE     = 'large';
my $BAD_CONTENT_SIZE = 'enormous';

my $CONTENT_TYPE     = 'images';
my $BAD_CONTENT_TYPE = 'birds';

my ( $success, $error, $cached_file_path ) = ( undef, undef, undef );

# No User ID passed in should fail.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        content_type => $CONTENT_TYPE,
                                                                        content_size => $CONTENT_SIZE,
                                                                     );

is( $success, 0, 'No User ID passed in failed.' );
is( $error, 'Cannot confirm cached file directory. Invalid User or Content information.', 'Proper error message returned for no User ID.' );

# Invalid User ID passed in should fail.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $INVALID_USER_ID,
                                                                        content_type => $CONTENT_TYPE,
                                                                        content_size => $CONTENT_SIZE,
                                                                     );

is( $success, 0, 'Invalid User ID passed in failed.' );
is( $error, 'Cannot confirm cached file directory. Invalid User information.', 'Proper error message returned for invalid User ID.' );


( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $NEW_USER_ID,
                                                                        content_type => $CONTENT_TYPE,
                                                                        content_size => $CONTENT_SIZE,
                                                                     );

is( $success, 0, 'Non-existent User ID passed in failed.' );
is( $error, 'Cannot confirm cached file directory. Invalid User information.', 'Proper error message returned for non-existent User ID.' );

# No Content Type passed in should fail.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $EXISTING_USER_ID,
                                                                        content_size => $CONTENT_SIZE,
                                                                     );

is( $success, 0, 'No Content Type passed in failed.' );
is( $error, 'Cannot confirm cached file directory. Invalid User or Content information.', 'Proper error message returned for no Content Type.' );

# Invalid Content Type should fail.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $EXISTING_USER_ID,
                                                                        content_type => $BAD_CONTENT_TYPE,
                                                                        content_size => $CONTENT_SIZE,
                                                                     );

is( $success, 0, 'Invalid Content Type passed in failed.' );
is( $error, 'An error occurred. Invalid Content Type passed in.', 'Proper error message returned for invalid Content Type.' );

# Content Type 'images' but not Content Size should fail.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $EXISTING_USER_ID,
                                                                        content_type => $CONTENT_TYPE,
                                                                     );

is( $success, 0, 'No Content Size passed in failed.' );
is( $error, 'Cannot confirm cached file directory. Invalid User Content information.', 'Proper error message returned for no Content Size.' );

# Content Type 'images' but invalid  Content Size should fail.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $EXISTING_USER_ID,
                                                                        content_type => $CONTENT_TYPE,
                                                                        content_size => $BAD_CONTENT_SIZE,
                                                                     );

is( $success, 0, 'Invalid Content Size passed in failed.' );
is( $error, 'Cannot confirm cached file directory. Invalid User Content information.', 'Proper error message returned for invalid Content Size.' );

# Valid credentials should succeed.
( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $EXISTING_USER_ID,
                                                                        content_type => $CONTENT_TYPE,
                                                                        content_size => $CONTENT_SIZE,
                                                                     );

is( $success, 1, 'Valid parameters passed.' );
is( $error, undef, 'No error message returned for valid parameters.' );
is( $cached_file_path, '/data/cached_files/user_content/images/large/2/2/2', 'Valid cached files dir returned.' );

