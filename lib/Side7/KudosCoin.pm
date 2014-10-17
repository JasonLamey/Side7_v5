package Side7::KudosCoin;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.
use Rose::DB::Object::QueryBuilder;
use Try::Tiny;

use Side7::Globals;

use version; our $VERSION = qv( '0.1.4' );

=pod

=head1 NAME

Side7::KudosCoin

=head1 DESCRIPTION

This package adds facilities for management of the purchase, usage, and tracking
of Side 7 Kudos Coins.

=head1 SCHEMA INFORMATION

    Table name: kudos_coin_ledger

    | id          | bigint(20) unsigned | NO   | PRI | NULL    |       |
    | user_id     | bigint(20) unsigned | NO   | MUL | NULL    |       |
    | timestamp   | datetime            | NO   |     | NULL    |       |
    | amount      | int(11)             | NO   |     | NULL    |       |
    | description | text                | NO   |     | NULL    |       |
    | purachased  | tinyint(1)          | NO   |     | 0       |       |

=head1 RELATIONSHIPS

=over

=item Side7::User

Many to one relationship, with user_id being the FK to users.id

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'kudos_coin_ledger',
    columns => [
        id            => { type => 'serial',  not_null => 1 },
        user_id       => { type => 'integer', not_null => 1 },
        timestamp     => { type => 'datetime', not_null => 1, default => 'now()' },
        amount        => { type => 'integer', not_null => 1 },
        description   => { type => 'text',    not_null => 1 },
        purchased     => { type => 'boolean', not_null => 1, default => 0 },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'user_id' ], [ 'timestamp' ], [ 'user_id', 'timestamp' ], ],
    foreign_keys =>
    [
        user =>
        {
            type       => 'many to one',
            class      => 'Side7::User',
            column_map => { user_id => 'id' },
        },
    ],
);

=head1 METHODS


=head2 get_current_balance()

Returns the current Kudos Coin balance for a User.

Parameters:

=over 4

=item user_id: The User for whom to get the balance.

=back

    my $current_balance = Side7::KudosCoins->get_current_balance( user_id => $user_id );

=cut

sub get_current_balance
{
    my ( $self, %args ) = @_;

    my $user_id = delete $args{'user_id'} // undef;

    if ( ! defined $user_id )
    {
        return 0;
    }

    $user_id =~ s/\D//g;

    my ( $sql, $bind ) = Rose::DB::Object::QueryBuilder::build_select(
                                                            dbh     => $DB->dbh,
                                                            select  => 'SUM( amount ) as total',
                                                            tables  => [ 'kudos_coin_ledger' ],
                                                            columns => { kudos_coin_ledger => [ qw( amount user_id ) ] },
                                                            query   => [ user_id => $user_id ],
                                                            query_is_sql => 1,
                                                          );

    my $sth = $DB->dbh->prepare( $sql );
    $sth->execute( @{ $bind } );

    my $row = $sth->fetchrow_hashref();

    $sth->finish();

    return $row->{'total'} // 0;
}


=head2 give_kudos_coins()

Gives Kudos Coins to a User, along with a reason.  Also records the transaction to the Audit Log. Returns a boolean.

Parameters:

=over 4

=item user_id: The User for whom to get the balance.

=item amount: The number of Kudos coins to award.

=item description: The reason for the award.

=item purchased: Boolean as to whether or not these coins were purchased.

=back

    my $success = Side7::KudosCoins->give_kudos_coins(
                                                        user_id     => $user_id,
                                                        amount      => $amount,
                                                        description => $description,
                                                        purchased   => $purchased,
                                                     );

=cut

sub give_kudos_coins
{
    my ( $self, %args ) = @_;

    my $user_id     = delete $args{'user_id'}     // undef;
    my $amount      = delete $args{'amount'}      // undef;
    my $description = delete $args{'description'} // undef;
    my $purchased   = delete $args{'purchased'}   // 0;

    if ( ! defined $user_id )
    {
        $LOGGER->warning( 'Invalid User ID provided when giving Kudos Coins.' );
        return ( 0, 'There was an error adding Kudos Coins. This has been reported.' );
    }

    if ( ! defined $amount )
    {
        $LOGGER->warning( 'Undefined Amount passed in when giving Kudos Coins.' );
        return ( 0, 'There was an error adding Kudos Coins. This has been reported.' );
    }

    if ( $amount == 0 )
    {
        $LOGGER->warning( 'Amount with value >0< (zero) passed in when giving Kudos Coins.' );
        return ( 0, 'There was an error adding Kudos Coins. This has been reported.' );
    }

    $user_id =~ s/\D//g;

    my $ledger = Side7::KudosCoin->new(
                                        user_id     => $user_id,
                                        amount      => $amount,
                                        description => $description,
                                        purchased   => $purchased,
                                        timestamp   => 'now',
                                      );
    #try
    #{
        $ledger->save();
    #}
    #catch
    #{
        #$LOGGER->error( 'Could not give Kudos Coins to User #>' . $user_id . '<: ' . $_ );
        #return ( 0, 'There was an error adding Kudos Coins. This has been reported.' );
    #}

    return ( 1, undef );
}


=head2 get_formatted_timestamp()

Returns a properly formatted timestamp for an individual ledger entry.

Parameters:

=over 4

=item date_format: The data format to return the timestamp in. Defaults to '%a, %c'.

=back

    my $timestamp = $record->get_formatted_timestamp();

=cut

sub get_formatted_timestamp
{
    my ( $self, %args ) = @_;

    return if ! defined $self;

    my $date_format = delete $args{'date_format'} // '%a, %c';

    my $date = $self->timestamp( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head1 FUNCTIONS


=head2 function_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package::function_name();

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
