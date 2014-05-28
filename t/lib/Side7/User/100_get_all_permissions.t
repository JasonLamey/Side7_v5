use strict;
use warnings;

use Test::More tests => 6;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User';

# Attempt to get a User.

my $USER_ID       = 1; # Esquire account
my $PERMISSION    = 'can_login';

my $user = Side7::User->new( id => $USER_ID );
my $loaded = $user->load( speculative => 1, with_object => [ 'account' ] );

isnt( $loaded, 0, 'User account loaded successfully.' );
isa_ok( $user, 'Side7::User' );

SKIP: {
    skip 'No user loaded.', 2 if $loaded == 0;

    my $permissions = $user->get_all_permissions(); 
    is( ref( $permissions ), 'ARRAY', 'User permission array returned.' );
    ok( scalar( @{ $permissions } ) > 0, 'User has defined permissions.' );
}
