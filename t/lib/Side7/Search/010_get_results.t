use strict;
use warnings;

use Test::More tests => 4;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Search';

# Attempt to get a User.

my $SEARCH_TERM = 'BadKarma';

my ( $results, $error ) = Side7::Search->get_results(   
                                                        look_for => $SEARCH_TERM,
                                                        page     => 1,
                                                        size     => 'small',
                                                    );

is( ref( $results ), 'ARRAY', 'Search results array returned.' );
is( $error, undef, 'No error message returned.' ) ||
    diag( 'Search Results Error: ' . $error );
