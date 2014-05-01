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

Returns a string that has the BBCode-like markup in the passed in string parsed into HTML.  
C<%args> is a hash of arguments that can be passed to Parse::BBCode to customize its output.

Parameters:

=over 4

=item original_text: The original text variable to parse.

=item args: Hashref of additional options, such as smilies. TODO: Detail this.

=back

    $parsed_text = Side7::Utils::Text::parse_bbcode_markup( $original_text, \%args );

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


=head2 true_false_to_int()

Returns an integer value for true/false.

Parameters:

=over 4

=item text: The text to evaluate.

=back

    my $int = Side7::Utils::Text::true_false_to_int( $text );

=cut

sub true_false_to_int
{
    my ( $text ) = @_;

    return 0 if ! defined $text;

    if ( lc( $text ) eq 'true' )
    {
        return 1;
    }

    return 0;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
