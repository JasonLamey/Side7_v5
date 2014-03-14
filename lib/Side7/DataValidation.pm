package Side7::DataValidation;

use strict;
use warnings;

use Side7::Globals;

=pod


=head1 NAME

Side7::DataValidation


=head1 DESCRIPTION

Data Validation for user-input data.


=head1 METHODS

=head2 is_password_valid

    $result = Side7::DataValidation::is_password_valid( $password );

Ensures that a password matches the security criteria. Returns true if valid.

=cut

sub is_password_valid
{
    my ( $password ) = @_;

    my $success = 1;
    if ( $password !~ /[a-z]+/i )
    {
        $success = 0;
    }
    if ( $password !~ /[0-9]+/ )
    {
        $success = 0;
    }
    if ( $password !~ /[@!#$%^&*.-_+]+/ )
    {
        $success = 0;
    }

    return $success;
}


=head2 has_valid_length

    $result = Side7::DataValidation::has_valid_lenth( $value, $min_length, $max_length );

Ensures the length of the string is within the defined parameters.  Min_length defaults to 0. If Max_length is omitted the check ensures that the length is simply larger than the min_length.

=cut

sub has_valid_length
{
    my ( $text, $min_length, $max_length ) = @_;

    $min_length ||= 0;

    my $success = 0;

    if ( defined $max_length )
    {
        if ( 
            length( $text ) >= $min_length 
            && 
            length( $text ) <= $max_length )
        {
            $success = 1;
        }
    }
    else
    {
        if (
            length( $text ) >= $min_length
        )
        {
            $success = 1;
        }
    }

    return $success;
}


=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
