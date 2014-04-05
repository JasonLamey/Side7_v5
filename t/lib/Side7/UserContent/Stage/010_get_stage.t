use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::UserContent::Stage';

# Attempt to get a Stage object.

my $STAGE_ID = 4; # Stage, 'Finished Piece'.
my $BAD_STAGE_ID = 1234567890;

my $stage = Side7::UserContent::Stage->new( id => $STAGE_ID );
my $loaded = $stage->load( speculative => 1 );

isnt( $loaded, 0, 'Loaded Stage object from database.' );

isa_ok( $stage, 'Side7::UserContent::Stage', 'User Content Stage object' );

is( $stage->stage(), 'Finished Piece', 'Pulled proper Stage name.' );

my $no_stage = Side7::UserContent::Stage->new( id => $BAD_STAGE_ID );
$loaded = $no_stage->load( speculative => 1 );

is( $loaded, 0, 'Did not load invalid User Content Stage object from database.' );
