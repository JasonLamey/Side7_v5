use strict;
use warnings;

use Test::More tests => 9;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Account';

# Attempt to get an account.

my $USER_ID = 2; # BadKarma account.

my $account = Side7::Account->new( user_id => $USER_ID );

my $loaded = $account->load( speculative => 1 );

isnt( $loaded, 0, 'Account loaded.' );

isa_ok($account, 'Side7::Account');

my $full_name = $account->full_name();

is( $full_name, 'Jason Lamey', 'Can get full_name.' );

my $birthday = $account->get_formatted_birthday();

is( $birthday, '15 January, 1973', 'Can get formatted birthday' );

my $expires_on = $account->get_formatted_subscription_expires_on();

is( $expires_on, '16 January, 3000', 'Can get formatted subscription expiration date.' );

my $created_at = $account->get_formatted_created_at();

is( $created_at, 'Monday, 16 November, 1998', 'Can get formatted created_at date.' );

my $updated_at = $account->get_formatted_updated_at();

is( $updated_at, 'Tuesday, 01 July, 2008', 'Can get formatted updated_at date.' );

