{
    # Fields for validating
    fields => [ qw/username email_address birthday password password_confirmation agree_to_rules referred_by/ ],
    filters => [
        qr/.+/        => filter(qw/trim strip/),    
        email_address => filter('lc'),
    ],
    checks => [
        username              => is_required("A Username is required."),
        email_address         => is_required("An E-mail Address is required."),
        password              => is_required("A Password is required."),
        password_confirmation => is_required("Password Confirmation is required."),
        birthday              => is_required("Birthday is required."),
        agree_to_rules        => is_required("You must agree to the rules before you can sign up."),

        username => is_long_between( 3, 45, 'Your Username should have between 3 and 45 characters.' ),
        username => is_like( qr/^[a-z0-9_]{3,45}$/i, "Invalid characters in your Username.  Please use A-Z, 0-9, _ (underscore), only." ),

        email_address => sub
        {
            check_email($_[0], "Please enter a valid E-mail Address.");
        },

        password              => is_long_between( 8, 45, 'Your Password should have between 4 and 45 characters.' ),
        password_confirmation => is_equal("password", "Passwords don't match"),

        birthday => is_like( qr/^\d{4}-\d{2}-\d{2}$/, "Invalid birthday format. Please use 'YYYY-MM-DD'." ),

        referred_by => sub
        {
            my ( $referred_by ) = @_;
            if ( defined $referred_by )
            {
                my $user = Side7::User::get_user_by_username( $referred_by );
                if ( ! defined $user || ! ref( $user ) eq 'Side7::User' )
                {
                    'The Referrer you specified (' . $referred_by . ') does not exist. Please check to ensure you have spelled the name correctly.';
                }
            }
        },
    ],
}
