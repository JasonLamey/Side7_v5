use strict;
use warnings;

use Test::More tests => 9;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::Pagination';

# Attempt to get pagination hash.

my $TOTAL            = 500;
my $PAGE             = 4;
my $PAGINATION_LIMIT = 50;

my $pagination = Side7::Utils::Pagination::get_pagination( 
            {
                total_count      => $TOTAL,
                page             => $PAGE,
                pagination_limit => $PAGINATION_LIMIT,
            }
);

is( $pagination->{'first_item'}, 151, 'First item is correct.' );
is( $pagination->{'last_item'},  200, 'Last item is correct.' );
is( $pagination->{'total_count'}, 500, 'Total count is correct.' );
is( $pagination->{'next_page'}, 5, 'Next page is correct.' );
is( $pagination->{'previous_page'}, 3, 'Previous page is correct.' );
is( $pagination->{'total_pages'}, 10, 'Total pages is correct.' );
is( $pagination->{'current_page'}, 4, 'Current page is correct.' );
