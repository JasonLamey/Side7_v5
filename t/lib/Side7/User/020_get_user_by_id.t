use strict;
use warnings;

use Test::More tests => 6;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User';

# Attempt to get a User.

my $USER_ID = 2; # BadKarma account.

my $user = Side7::User::get_user_by_id( $USER_ID );

isa_ok( $user, 'Side7::User' );

my $email_address = $user->email_address();

is( $email_address, 'badkarma@side7.com', 'Can retrieve e-mail address.' );

my $created_at = $user->get_formatted_created_at();

is( $created_at, 'Monday, 16 November, 1998', 'Can get formatted created_at date.' );

my $updated_at = $user->get_formatted_updated_at();

is( $updated_at, 'Tuesday, 01 July, 2008', 'Can get formatted updated_at date.' );

