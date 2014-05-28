use strict;
use warnings;

use Test::More tests => 7;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::KudosCoin';

# Attempt to get a ledger entry.

my $LEDGER_ID = 2; # BadKarma account starting balance. 465 value.

my $entry = Side7::KudosCoin->new( id => $LEDGER_ID );

my $loaded = $entry->load( speculative => 1 );

isnt( $loaded, 0, 'Kudos Coint Ledger entry loaded.' );
isa_ok( $entry, 'Side7::KudosCoin' );

is( $entry->amount(), 465, 'Can retrieve proper value.' );

my $created_at = $entry->get_formatted_timestamp(); # 2009-01-26 02:28:02

is( $created_at, 'Mon, Jan 26, 2009 2:28:02 AM', 'Can get formatted timestamp.' );

is( $entry->description(), 'Imported Starting Balance', 'Can get entry description.' );

