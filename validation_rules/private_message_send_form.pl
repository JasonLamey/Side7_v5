{
    # Fields for validating
    fields => [ qw/ recipient body / ],
    filters => [
        qr/.+/        => filter(qw/trim strip/),
    ],
    checks => [
        recipient => is_required("A Recipient is required."),
        body      => is_required("An E-mail Address is required."),

        body => is_long_at_least( 1, 'You must write *something* in the body of the message. No one wants a blank message.' ),

        recipient => sub
        {
            my ( $recipient ) = @_;
            if ( defined $recipient )
            {
                my $user = Side7::User::get_user_by_username( $recipient );
                if ( ! defined $user || ! ref( $user ) eq 'Side7::User' )
                {
                    'The Recipient you specified (' . $recipient . ') does not exist. Please check to ensure you have spelled the name correctly.';
                }
            }
        },
    ],
}
