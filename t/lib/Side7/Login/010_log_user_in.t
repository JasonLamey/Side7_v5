use strict;
use warnings;

use Test::More tests => 5;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Login';

# Attempt to log a known user in.

my $INVALID_USERNAME = 'testuser_testuser';
my $INVALID_PASSWORD = 'bad_password';
my $VALID_USERNAME = 'badkarma';
my $VALID_PASSWORD = 'Vengence';

my ( $rd_url, $user, $error );
# Invalid username test
( $rd_url, $user, $error ) = Side7::Login::user_login( { username => $INVALID_USERNAME, password => $INVALID_PASSWORD } );

is(
    $error, 
    "Invalid login attempt - User &gt;<b>$INVALID_USERNAME</b>&lt; doesn't exist in the database.", 
    'Invalid username/password didn\'t log in.'
);

# Invalid password test
( $rd_url, $user, $error ) = Side7::Login::user_login( { username => $VALID_USERNAME, password => $INVALID_PASSWORD } );

is(
    $error, 
    "Invalid login attempt - Bad username/password combo - Username: &gt;<b>$VALID_USERNAME</b>&lt;; " .
    "Password: &gt;<b>$INVALID_PASSWORD</b>&lt; " .
    'RD_URL: &gt;<b>/</b>&lt;',
    'Valid username/Invalid password didn\'t log in.' );

# Full valid credentials test
( $rd_url, $user, $error ) = Side7::Login::user_login( { username => $VALID_USERNAME, password => $VALID_PASSWORD } );

isa_ok( $user, 'Side7::User', 'User object' );


