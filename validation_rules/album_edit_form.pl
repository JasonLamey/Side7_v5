{
    # Fields for validating
    fields => [ qw/name system/ ],
    filters => [
        qr/.+/        => filter(qw/trim strip/),    
        email_address => filter('lc'),
    ],
    checks => [
        name     => is_required("An Album name is required."),

        referred_by => sub
        {
            my ( $referred_by ) = @_;
            if ( defined $referred_by )
            {
                if ( $referred_by == 1 )
                {
                    'The Album you specified is a system Album. System Albums are not editable.';
                }
            }
        },
    ],
}
