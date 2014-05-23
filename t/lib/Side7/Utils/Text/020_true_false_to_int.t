use strict;
use warnings;

use Test::More tests => 15;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::Text';

# Ensure that we can convert a true or false value to an integer (0, 1).

# True values
is( Side7::Utils::Text::true_false_to_int( 'true' ),  1, 'Lowercase true evaluates to 1' );
is( Side7::Utils::Text::true_false_to_int( 'TRUE' ),  1, 'Uppercase true evaluates to 1' );
is( Side7::Utils::Text::true_false_to_int( 'True' ),  1, 'Mixedcase true evaluates to 1' );
is( Side7::Utils::Text::true_false_to_int( 1 ),       1, 'Numerical 1 evaluates to 1' );
is( Side7::Utils::Text::true_false_to_int( '1' ),     1, 'String 1 evaluates to 1' );

# False values
is( Side7::Utils::Text::true_false_to_int( 'false' ), 0, 'Lowercase false evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( 'FALSE' ), 0, 'Uppercase false evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( 'False' ), 0, 'Mixedcase false evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( 'Ralph' ), 0, 'Non-true/false value evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( '0' ),     0, 'String 0 evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( '7' ),     0, 'String 7 evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( 0 ),       0, 'Numerical 0 evaluates to 0' );
is( Side7::Utils::Text::true_false_to_int( 9 ),       0, 'Numerical 9 evaluates to 0' );
