use strict;
use warnings;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Test::More tests => 6;

use_ok('Side7');
use_ok('Side7::Login');

my $SESSION_USERNAME = 'badkarma';
my $VALID_USERNAME   = 'badkarma';
my $INVALID_USERNAME = 'foo';

my $result = '';
# No Username, No session username, should fail.
$result = Side7::Login::user_authorization();

is( $result, 0, 'No session username is not authorized.' );

# No Username, Session username, should pass.
$result = Side7::Login::user_authorization( session_username => $SESSION_USERNAME );

is( $result, 1, 'Valid session username passes.' );

# Session Username, Invalid Username, should fail.
$result = Side7::Login::user_authorization( session_username => $SESSION_USERNAME, username => $INVALID_USERNAME );

is( $result, 0, 'Session username, different username, is not authorized.' );

# Session Username, Valid Username, should pass.
$result = Side7::Login::user_authorization( session_username => $SESSION_USERNAME, username => $VALID_USERNAME );

is( $result, 1, 'Valid session username, same username, passes.' );
