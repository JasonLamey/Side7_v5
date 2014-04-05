use strict;
use warnings;

use Test::More tests => 6;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::Crypt';

# Attempt to get encrypted versions of text.

my $PASSWORD = 'bad_password';

my $SHA1_DIGEST     = 'eaacdf2d9ed66df2601c8b51ab4084db14336d11';
my $MD5_DIGEST      = '22764da5553c20cc80cc579db5bd2257';
my $S7_CRYPT        = 'S7gYp0dy8F51.';
my $OLD_DB_PASSWORD = '0a0d4b1b69fbebd1';

my $password = Side7::Utils::Crypt::sha1_hex_encode( $PASSWORD );

is( $password, $SHA1_DIGEST, 'Password encrypted into SHA1' );

$password = Side7::Utils::Crypt::md5_hex_encode( $PASSWORD );

is( $password, $MD5_DIGEST, 'Password encrypted into MD5' );

$password = Side7::Utils::Crypt::old_side7_crypt( $PASSWORD );

is( $password, $S7_CRYPT, 'Password encrypted into Old-style S7 Crypt' );

$password = Side7::Utils::Crypt::old_mysql_password( $PASSWORD );

is( $password, $OLD_DB_PASSWORD, 'Password encrypted into old MySQL Password' );
