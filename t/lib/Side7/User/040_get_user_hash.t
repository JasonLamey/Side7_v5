use strict;
use warnings;

use Test::More tests => 7;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User';

# Attempt to get a User.

my $USER_ID = 2; # BadKarma account.

my $user = Side7::User->new( id => $USER_ID );
my $loaded = $user->load( speculative => 1, with =>[ 'account', 'kudos_coins' ] );

isnt( $loaded, 0, 'User account loaded successfully.' );
isa_ok( $user, 'Side7::User' );

SKIP: {
    skip 'No User loaded.', 3 if $loaded == 0;

    my $user_hash = $user->get_user_hash_for_template();
    is( ref( $user_hash ), 'HASH', 'User hash is a hash ref.' );

    is( $user_hash->{'username'}, 'BadKarma', 'Retrieved username from hash.' );
    is( $user_hash->{'account'}->{'full_name'}, 'Jason Lamey', 'Retrieved full name from account.' );
}
