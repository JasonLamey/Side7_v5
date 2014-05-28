use strict;
use warnings;

use Test::More tests => 4;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Search';

# Attempt to get a User.

my $SEARCH_TERM = 'BadKarma';

my $history = Side7::Search::get_history(   
                                            search_term => $SEARCH_TERM,
                                        );

is( ref( $history ), 'ARRAY', 'Search results history array returned.' );
ok( scalar( @{ $history } ) > 0, 'Search results history array has elements.' );
