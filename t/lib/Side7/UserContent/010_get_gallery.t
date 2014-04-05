use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent';

# Attempt to get a User Gallery that has content.

my $USER_ID = 2; # BadKarma account.
my $BAD_USER_ID = 999999999;

my $gallery = Side7::UserContent::get_gallery( $USER_ID );

is( ref( $gallery ), 'ARRAY', 'Gallery is an array ref.' )
    || diag( 'Gallery looks like this: ' . Dumper( \$gallery ) );

cmp_ok( scalar( @{$gallery} ), '>', 0, 'User Gallery has content records.' );

my $content = $gallery->[0];

is( ref( $content ), 'HASH', 'Gallery content is a hash ref.' );

my $no_gallery = Side7::UserContent::get_gallery( $BAD_USER_ID );

is( ref( $no_gallery ), 'ARRAY', 'Empty gallery is an array.' );

cmp_ok( scalar( @{$no_gallery} ), '==', 0, 'Empty gallery is indeed empty.' );
