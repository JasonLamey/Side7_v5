use strict;
use warnings;

use Test::More tests => 5;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User';

# Attempt to get a User.

my $USER_ID = 2; # BadKarma account.

my $user = Side7::User->new( id => $USER_ID );
my $loaded = $user->load( speculative => 1 );

isnt( $loaded, 0, 'User account loaded successfully.' );
isa_ok( $user, 'Side7::User' );

SKIP: {
    skip 'No user loaded.', 1 if $loaded == 0 ;

    my $user_content_dir = $user->get_content_directory();
    is( $user_content_dir, '/data/galleries/2/2/2/', 'Retrieved appropriate directory.' );
}
