{
    # Fields for validating
    fields => [ qw/username email_address birthday birthday_visibility sex country delete_on subscription_expires_on/ ],
    filters => [
        qr/.+/        => filter(qw/trim strip/),    
        email_address => filter('lc'),
    ],
    checks => [
        username            => is_required("A Username is required."),
        email_address       => is_required("An E-mail Address is required."),
        birthday            => is_required("A Birthday is required."),
        birthday_visibiilty => is_required("Birthday Visibility is required."),
        sex                 => is_required("Sex is required."),
        country             => is_required("Country is required."),

        username => is_long_between( 3, 45, 'Your Username should have between 3 and 45 characters.' ),
        username => is_like( qr/^[a-z0-9_]{3,45}$/i, "Invalid characters in your Username.  Please use A-Z, 0-9, _ (underscore), only." ),

        email_address => sub
        {
            check_email($_[0], "Please enter a valid E-mail Address.");
        },

        birthday => is_like( qr/^\d{4}-\d{2}-\d{2}$/, "Invalid birthday format. Please use 'YYYY-MM-DD'." ),
        delete_on => is_like( qr/^\d{4}-\d{2}-\d{2}$/, "Invalid Delete On format. Please use 'YYYY-MM-DD'." ),
        subscription_expires_on => is_like( qr/^\d{4}-\d{2}-\d{2}$/, "Invalid Subscription expiration date format. Please use 'YYYY-MM-DD'." ),

        birthday_visibility => is_in( [ 1, 2, 3 ], 'Birthday Visibility must be set' ),

    ],
}
