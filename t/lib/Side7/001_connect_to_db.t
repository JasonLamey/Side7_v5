use Test::More;
use Test::Mojo;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok('Side7');
use_ok('Side7::DB');

# Establish a db connection
my $db = Side7::DB->new();

isa_ok($db, 'Side7::DB', 'db is a Side7::DB object');

done_testing();
