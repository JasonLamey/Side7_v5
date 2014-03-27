package Side7::Utils::Text;

use strict;
use warnings;

use Parse::BBCode;

use Side7::Globals;


=head1 NAME

Side7::Utils::Text;


=head1 DESCRIPTION

Supplies tools and functionality for parsing text in various and sundry ways.


=head1 FUNCTIONS

=head2 parse_bbcode_markup()

    $parsed_text = Side7::Utils::Text::parse_bbcode_markup( $original_text, \%args );

Returns a string that has the BBCode-like markup in the passed in string parsed into HTML.  C<%args> is a hash of arguments that can be passed
to Parse::BBCode to customize its output.

=cut

sub parse_bbcode_markup
{
    my ( $incoming_text, $args ) = @_;

    return undef if ! defined $incoming_text;

    my $smileys = (defined $args->{'smilies'}) ? 1 : 0;

    my $parser = Parse::BBCode->new(
                    {
                        attribute_quote => q/'"/,
                        close_open_tags => 1,
                    }
                );

    my $parsed_text = $parser->render( $incoming_text );

    return $parsed_text;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
