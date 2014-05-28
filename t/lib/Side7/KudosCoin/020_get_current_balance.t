use strict;
use warnings;

use Test::More tests => 8;

use DateTime;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::User';
use_ok 'Side7::KudosCoin';
use_ok 'Side7::KudosCoin::Manager';

# Create User.
my $user = Side7::User->new(
                                username      => 'Test', 
                                password      => Side7::Utils::Crypt::sha1_hex_encode( 'test' ),
                                email_address => 'test@side7.com',
                                created_at    => 'now()',
                                updated_at    => 'now()',
                           );
$user->save();

isa_ok( $user, 'Side7::User', 'Side7::User' );

SKIP:
{
    skip 'User not saved.', 3 if ref( $user ) ne 'Side7::User';

    # Assign known amounts of KudosCoins to User.
    my @coins = ( 5, 50, 100, 45 );
    my $i     = 1;

    foreach my $coin ( @coins )
    {
        my $now = DateTime->now();
        my $kudo = Side7::KudosCoin->new( 
                                            user_id     => $user->id(),
                                            amount      => $coin, 
                                            description => 'test ' . $i,
                                            timestamp   => $now,
                                        );
        $kudo->save();
        sleep( 1 );

        $i++;
    }

    # Get current balance.
    my $balance = Side7::KudosCoin->get_current_balance( user_id => $user->id() );

    is( $balance, 200, 'Proper balance returned.' );

    # Delete Kudos Coin records.
    my $num_coins_deleted = Side7::KudosCoin::Manager->delete_kudos_coins(
                                                        where =>
                                                        [
                                                            user_id => $user->id(),
                                                        ]
                                                                          );

    is( $num_coins_deleted, 4, 'Deleted KudosCoins records.' );

    # Delete User.
    my $deleted = $user->delete();
    is( $deleted, 1, 'Deleted test user.' ) ||
        diag( 'Error: ' . $user->error() );
}
