package Side7::User::ChangePassword;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.1' );

=pod


=head1 NAME

Side7::User::ChangePassword


=head1 DESCRIPTION

This library handles the saving, looking up, and removal of interim password changes.


=head1 SCHEMA INFORMATION

    Table name: user_password_changes

    | id                | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | confirmation_code | varchar(60)         | NO   | UNI | NULL    |                |
    | user_id           | bigint(20) unsigned | NO   | MUL | NULL    |                |
    | new_password      | varchar(45)         | NO   |     | NULL    |                |
    | is_a_reset        | boolean             | NO   |     | NULL    |                |
    | created_at        | datetime            | NO   | MUL | NULL    |                |
    | updated_at        | datetime            | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

One-to-one relationship with Side7::User, using user_id as the FK.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_password_changes',
    columns => [
        id                => { type => 'serial',   not_null => 1 },
        confirmation_code => { type => 'varchar',  length   => 60,  not_null => 1 },
        user_id           => { type => 'integer',  not_null => 1 },
        new_password      => { type => 'varchar',  length   => 45,  not_null => 1 },
        is_a_reset        => { type => 'boolean',  default  => 0,   not_null => 1 },
        created_at        => { type => 'datetime', not_null => 1,   default  => 'now()' },
        updated_at        => { type => 'datetime', not_null => 1,   default  => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [
                    [ 'confirmation_code', 'user_id', 'is_a_reset' ],
                    [ 'confirmation_code', 'user_id' ],
                    [ 'user_id' ],
                    [ 'confirmation_code' ],
                    [ 'created_at' ]
                  ],
    foreign_keys =>
    [
        user =>
        {
            type       => 'one to one',
            class      => 'Side7::User',
            column_map => { user_id => 'id' },
        },
    ],
);


=head1 METHODS


=head2 generate_random_password()

Returns a C<string> of X length containing random characters.

Parameters:

=over 4

=item length: an integer to determine the length of the password. Defaults to 8

=back

    my $random_password = Side7::User::ChangePassword->generate_random_password( $length );

=cut

sub generate_random_password
{
    my ( $self, $length ) = @_;

    $length //= 8;

    my @characters = ( 'A'..'Z', 0..9, 'a'..'z', '-', '_', '.' );
    my $string = join( '', @characters[ map{ rand @characters } 1 .. $length ] );

    return $string;
}


=head2 reset_password()

Resets a User's password to the value stored in the user_changed_passwords table. Requires the
C<confirmation_code>, and will look up the User from there. Returns a hashref containing a boolean for success,
as well as any error message on a failure. C<$hashref->{'error'}> contains any error message. C<$hashref->{'success'}> contains the boolean.

Parameters:

=over 4

=item confirmation_code: The confirmation_code e-mailed to the user to confirm the resetting of the password.

=back

    my $changed = Side7::User::ChangePassword->reset_password( $confirmation_code );

=cut

sub reset_password
{
    my ( $self, $confirmation_code ) = @_;

    if ( ! defined $confirmation_code )
    {
        $LOGGER->error( 'Null confirmation_code passed in.' );
        return { success => 0, error => 'Invalid confirmation code defined.' };
    }

    my $change_results = {};
    if ( length( $confirmation_code ) < 40 )
    {
        $LOGGER->error( 'Invalid confirmation code >' . $confirmation_code . '< passed in.' );
        $change_results->{'success'} = 0;
        $change_results->{'error'}   = 'The confirmation code >' . $confirmation_code .
                                        '< is invalid. Please check your code and try again.';
        return $change_results;
    }

    my $change = Side7::User::ChangePassword->new( confirmation_code => $confirmation_code );
    my $loaded = $change->load( speculative => 1, with => [ 'user' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->error( 'No matching User account for confirmation code >' . $confirmation_code . '< was found.' );
        $change_results->{'success'} = 0;
        $change_results->{'error'}   = 'The confirmation code >' . $confirmation_code .
                                        '< is invalid. Please check your code and try again.';
        return $change_results;
    }

    my $new_encoded_password = Side7::Utils::Crypt::sha1_hex_encode( $change->new_password() );
    my $original_password    = $change->user->password();

    $change->user->password( $new_encoded_password );
    $change->user->updated_at( 'now' );
    $change->user->save;

    $change->delete;

    $change_results->{'success'}           = 1;
    $change_results->{'new_password'}      = $change->new_password;
    $change_results->{'user'}              = $change->user;

    return $change_results;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
