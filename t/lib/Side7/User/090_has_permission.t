use strict;
use warnings;

use Test::More tests => 6;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User';

# Attempt to get a User.

my $USER_ID       = 1; # Esquire account
my $PERMISSION    = 'can_login';
my $NO_PERMISSION = 'can_promote_owner';

my $user = Side7::User->new( id => $USER_ID );
my $loaded = $user->load( speculative => 1, with_object => [ 'account' ] );

isnt( $loaded, 0, 'User account loaded successfully.' );
isa_ok( $user, 'Side7::User' );

SKIP: {
    skip 'No user loaded.', 2 if $loaded == 0 ;

    my $has_permission = $user->has_permission( $PERMISSION ); 
    is( $has_permission, 1, 'User has a permission he should.' );

    $has_permission = $user->has_permission( $NO_PERMISSION ); 
    is( $has_permission, 0, 'User does not have a permission he shouldnt.' );
}
