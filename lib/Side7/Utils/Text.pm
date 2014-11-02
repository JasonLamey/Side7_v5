package Side7::Utils::Text;

use strict;
use warnings;

use Parse::BBCode;
use Parse::BBCode::HTML;
use Regexp::Common qw/profanity profanity_us/;
use HTML::Escape;

use Side7::Globals;

use version; our $VERSION = qv( '0.1.10' );


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

    my $parser = Parse::BBCode->new(
                    {
                        attribute_quote   => q/'"/,
                        close_open_tags   => 1,
                        strict_attributes => 0,
                        smileys         => {
                                            base_url => '/images/emoticons/',
                                            icons    => {
                                                            qw/
                                                                :alien:     alien.png
                                                                :blush:     blush.png
                                                                :'(         cwy.png
                                                                <3          heart.png
                                                                :pinch:     pinch.png
                                                                :sick:      sick.png
                                                                :)          smile.png
                                                                =)          smile.png
                                                                :-)         smile.png
                                                                :wassat:    wassat.png
                                                                :angel:     angel.png
                                                                :cheerful:  cheerful.png
                                                                :devil:     devil.png
                                                                :getlost:   getlost.png
                                                                :kissing:   kissing.png
                                                                :kiss:      kissing.png
                                                                :pouty:     pouty.png
                                                                :sideways:  sideways.png
                                                                :P          tongue.png
                                                                :p          tongue.png
                                                                :b          tongue.png
                                                                :whistling: whistling.png
                                                                :angry:     angry.png
                                                                >:(         angry.png
                                                                8-)         cool.png
                                                                8)          cool.png
                                                                :cool:      cool.png
                                                                :dizzy:     dizzy.png
                                                                :D          grin.png
                                                                =D          grin.png
                                                                :laughing:  laughing.png
                                                                :laugh:     laughing.png
                                                                :(          sad.png
                                                                :sad:       sad.png
                                                                :silly:     silly.png
                                                                :unsure:    unsure.png
                                                                ;)          wink.png
                                                                :wink:      wink.png
                                                                :blink:     blink.png
                                                                :erm:       ermm.png
                                                                :ermm:      ermm.png
                                                                :happy:     happy.png
                                                                :ninja:     ninja.png
                                                                :O          shocked.png
                                                                :0          shocked.png
                                                                :o          shocked.png
                                                                :sleeping:  sleeping.png
                                                                :woot:      w00t.png
                                                                :w00t:      w00t.png
                                                                :love:      wub.png
                                                            /
                                                        },
                                            format => '<img src="%s" alt="%s" title="%2$s" border="0">',
                                           },
                        url_finder => {
                                        max_length  => 50,
                                        # sprintf format:
                                        format      => '<a href="%s" rel="nofollow">%s</a>',
                                      },
                        tags => {
                                    Parse::BBCode::HTML->defaults,

                                    # Custom/overridden tags
                                    noparse => '<pre>%{html}s</pre>',
                                    code => {
                                                code => sub {
                                                                my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                                my $code_name = ( defined $attr ) ? uc( $attr ) . ' ' : '';
                                                                my $pre_class = ( defined $attr ) ? ' class="sh_' . lc( $attr ) . '"' : '' ;
                                                                $content = Parse::BBCode::escape_html( $$content );
                                                                qq{<div class="bbcode_code_header">$code_name} . qq{Code:\n} .
                                                                qq{<div class="bbcode_code_body"><pre$pre_class>$content</pre></div></div>}
                                                            },
                                                parse => 0,
                                                class => 'block',
                                            },
                                    table => {
                                                code  => sub {
                                                                my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                                my $output = "<table border='1'>$$content</table>";
                                                                $output =~ s/(<\/?t[rhd]>)<br>/$1/gi;
                                                                $output
                                                             },
                                                parse => 1,
                                                class => 'block',
                                             },
                                    tr    => '<tr>%{parse}s</tr>',
                                    th    => '<th>%{parse}s</th>',
                                    td    => '<td>%{parse}s</td>',
                                    hr => {
                                            class  => 'block',
                                            output => '<hr size="1">',
                                            single => 1,
                                          },
                                    font  => {
                                                code => sub {
                                                                my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                                if ( defined $attr )
                                                                {
                                                                    $content = '<span style="font-family: ' .
                                                                                $attr . '">' . $$content . '</span>';
                                                                }
                                                                else
                                                                {
                                                                    $content = Parse::BBCode::escape_html( $$content );
                                                                }
                                                                $content
                                                            },
                                                parse => 1,
                                                class => 'inline',
                                             },
                                    size => {
                                                code => sub {
                                                                my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                                my %font_sizes = (
                                                                                    1 => '8pt',
                                                                                    2 => '10pt',
                                                                                    3 => '12pt',
                                                                                    4 => '14pt',
                                                                                    5 => '18pt',
                                                                                    6 => '24pt',
                                                                                    7 => '36pt',
                                                                                 );
                                                                $content = '<span style="font-size: ' . $font_sizes{$attr} .
                                                                            '">' . $$content . '</span>';
                                                            },
                                                parse => 1,
                                                class => 'inline',
                                            },
                                    right    => '<div style="text-align: right;">%{parse}s</div>',
                                    left     => '<div style="text-align: left;">%{parse}s</div>',
                                    center   => '<div style="text-align: center;">%{parse}s</div>',
                                    justify  => '<div style="text-align: justify;">%{parse}s</div>',
                                    s        => '<span style="text-decoration: line-through;">%{parse}s</span>',
                                    sup      => '<sup>%{parse}s</sup>',
                                    sub      => '<sub>%{parse}s</sub>',
                                    img      => {
                                                    code => sub {
                                                                    my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                                    if ( defined $attr )
                                                                    {
                                                                        my ( $width, $height ) = split( /x/, $attr );
                                                                        $content = qq{<img src="$$content" width="$width" height="$height" alt='' border="0">};
                                                                    }
                                                                    else
                                                                    {
                                                                        $content = qq{<img src="$$content" alt='' border="0">};
                                                                    }
                                                                    $content
                                                                },
                                                    parse => 0,
                                                    class => 'inline',
                                                },
                                    ul => {
                                            code => sub {
                                                            my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                            $content = qq{<ul>\n$$content\n</ul>};
                                                            $content =~ s/(<\/?li>)<br>/$1/gi;
                                                            $content
                                                        },
                                            parse => 1,
                                            class => 'block',
                                          },
                                    ol => {
                                            code => sub {
                                                            my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                            $content = qq{<ol>\n$$content\n</ol>};
                                                            $content =~ s/(<\/?li>)<br>/$1/gi;
                                                            $content
                                                        },
                                            parse => 1,
                                            class => 'block',
                                          },
                                    li => {
                                            code => sub {
                                                            my ( $parser, $attr, $content, $attribute_fallback ) = @_;
                                                            $content = qq{<li>$$content</li>};
                                                            $content
                                                        },
                                            parse => 1,
                                            class => 'block',
                                          },
                                },
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
