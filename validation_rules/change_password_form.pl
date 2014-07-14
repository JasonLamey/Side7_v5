{
    # Fields for validating
    fields => [ qw/old_password new_password confirm_new_password/ ],
    filters => [
        qr/.+/        => filter(qw/trim strip/),    
        email_address => filter('lc'),
    ],
    checks => [
        old_password          => is_required("Your Current Password is required."),
        new_password          => is_required("A New Password is required."),
        confirm_new_password  => is_required("New Password Confirmation is required."),

        new_password          => is_long_between( 4, 45, 'Your New Password should have between 4 and 45 characters.' ),
        new_password          => sub
        {
            my ( $value, $params, $keys ) = @_;

            if ( $params->{'new_password'} eq $params->{'old_password'} )
            {
                'Your new password and old password cannot be the same.';
            }
        },
        confirm_new_password  => is_equal("new_password", "New Passwords don't match"),
    ],
}
