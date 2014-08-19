{
    # Fields for validating
    fields => [ qw/ title blurb body link_to_article priority is_static not_static_after / ],
    filters => [
        qr/.+/        => filter( qw/ trim strip / ),    
        email_address => filter( 'lc' ),
    ],
    checks => [
        title    => is_required( "A Title is required." ),
        priority => is_required( "A Priority is required." ),

        not_static_after => is_required_if(
                                sub {
                                        my $params = shift;
                                        return $params->{'is_static'} == 1;
                                },
                                'A date for when the article loses its sticky status must be set.'
                            ),

        body => is_required_if(
                    sub {
                            my $params = shift;
                            return ( defined $params->{'link_to_article'} && $params->{'link_to_article'} ne '' );
                    },
                    'You must define either a Body or a Link To Article.'
                ),

        priority => is_in( [ 1, 2, 3 ], 'Priority must be set.' ),

    ],
}
