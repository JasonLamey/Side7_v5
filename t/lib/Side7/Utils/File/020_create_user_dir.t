use strict;
use warnings;

use Test::More tests => 9;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Side7::Globals;

use_ok 'Side7';
use_ok 'Side7::Utils::File';

my $NEW_USER_ID      = 987543; # Non-existent User ID.
my $EXISTING_USER_ID = 2;      # BadKarma's User ID.
my $INVALID_USER_ID  = 'INVALID_ID_3'; # Erroneous User ID that shouldn't exist.

# Attempt to create a user directory
my ( $success, $error ) = Side7::Utils::File::create_user_directory( $NEW_USER_ID );

is( $success, 1, 'Created a new User directory.' )
    || diag( 'Error: ' . $error );

# Won't re-create an existing user directory.
( $success, $error ) = Side7::Utils::File::create_user_directory( $EXISTING_USER_ID );

is( $success, 1, 'Successfully passed through for existing User directory.' )
    || diag( 'Error: ' . $error );

# Won't create a user directory for an invalid User ID.
( $success, $error ) = Side7::Utils::File::create_user_directory( $INVALID_USER_ID );

is( $success, 0, 'Did not create User directory for bad User ID.' );

is( $error, 'Invalid User credentials', 'Returned proper error message.' );

# Won't create a user directory for no User ID.
( $success, $error ) = Side7::Utils::File::create_user_directory();

is( $success, 0, 'Did not create User directory for missing User ID.' );

is( $error, 'Invalid User credentials', 'Returned proper error message.' );

my $tier1 = substr( $NEW_USER_ID, 0, 1 );
my $tier2 = substr( $NEW_USER_ID, 0, 3 );

is( rmdir( $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 . '/' . $NEW_USER_ID ), 1, 'Removed New User Directory' );
