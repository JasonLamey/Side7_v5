package Side7::Utils::Text;

use strict;
use warnings;

use Parse::BBCode;
use Regexp::Common qw/profanity profanity_us/;
use HTML::Escape;

use Side7::Globals;

use version; our $VERSION = qv( '0.1.9' );


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

    return if ! defined $incoming_text;

    my $smileys = ( defined $args->{'smilies'} ) ? 1 : 0;

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

    if (
            lc( $text ) eq 'true'
            ||
            $text eq '1'
            ||
            (
                $text =~ m/^\d+$/
                &&
                $text == 1
            )
       )
    {
        return 1;
    }

    return 0;
}


=head2 sanitize_text_for_html()

Removes HTML glyphs from text to sanitize it for HTML display.

Parameters:

=over 4

=item text: The text to evaluate.

=back

    my $new_text = Side7::Utils::Text::sanitize_text_for_html( $text );

=cut

sub sanitize_text_for_html
{
    my ( $text ) = @_;

    return if ! defined $text;

    my $escaped_text = HTML::Escape::escape_html( $text );

    return $escaped_text;
}


=head2 filter_profanity()

Receives a string variable and filters out any profanity found within it.

Parameters:

=over 4

=item text: The string to be parsed for profanity.

=back

    my $filtered_text = Side7::Utils::Text::filter_profanity( text => $text );

=cut

sub filter_profanity
{
    my ( %args ) = @_;

    my $text = delete $args{'text'} // undef;

    return '' if ! defined $text;

    #( my $filtered_text = $text ) =~ s/$RE{profanity}{contextual}/[****]/ig;
    ( my $filtered_text = $text ) =~ s/$RE{profanity}{us}{normal}{label}/[****]/ig;

    return $filtered_text;
}


=head2 get_pronoun()

Returns a string containing the appropriate pronoun based on the User's
stated sex and the part of speech. This is an attempt to present the User base
with gender-neutral pronoun options.

Parameters:

=over 4

=item sex: The listed sex from the User's account. Default: 'male', as is literarily custom.

=item part_of_speech: The role of the pronoun. Accepts: 'subject', 'object', 'poss_determiner', 'poss_pronoun', 'reflexive'. Default: 'poss_pronoun'.

=back

    my $pronoun = Side7::Utils::Text::get_pronoun( sex => $sex, part_of_speech => $speech );

=cut

sub get_pronoun
{
    my ( %args ) = @_;

    my $sex            = delete $args{'sex'}            // 'male';
    my $part_of_speech = delete $args{'part_of_speech'} // 'poss_pronoun';

    $sex = 'other' if ( lc( $sex ) ne 'male' && lc( $sex ) ne 'female' );

    my %pronouns = (
                    male   => {
                                subject         => 'he',
                                object          => 'him',
                                poss_determiner => 'his',
                                poss_pronoun    => 'his',
                                reflexive       => 'himself',
                              },
                    female => {
                                subject         => 'she',
                                object          => 'her',
                                poss_determiner => 'her',
                                poss_pronoun    => 'hers',
                                reflexive       => 'herself',
                              },
                    other  => {
                                subject         => 've',
                                object          => 'ver',
                                poss_determiner => 'vis',
                                poss_pronoun    => 'vis',
                                reflexive       => 'verself',
                              },
                   );

    return $pronouns{ lc( $sex ) }{ lc( $part_of_speech ) };
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
