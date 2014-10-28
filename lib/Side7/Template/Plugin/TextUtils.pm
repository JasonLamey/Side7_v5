package Side7::Template::Plugin::TextUtils;

=pod

=head1 NAME

Side7::Template::Plugin::TextUtils

=head1 DESCRIPTION

This package is a Template::Toolkit plugin to give templates direct access to Side7::Utils::Text;

=cut

use base qw( Template::Plugin );

use strict;
use warnings;

use Template::Plugin;
use Data::Dumper;

use Side7::Globals;
use Side7::Utils::Text;


=head1 METHODS


=head2 new()

Instantiates a new C<TextUtils> object for use by Template::Toolkit.

=cut

sub new
{
    my $class   = shift;
    my $context = shift;

    bless {}, $class;
}


=head2 load()

Used by Template::Toolkit to load the plugin.

=cut

sub load
{
    my ( $class, $context ) = @_;

    return $class;
}


=head2 parse_bbcode_markup()

Interface to Side7::Utils::Text::parse_bbcode_markup. Passes the text along to the function,
and returns its results.

Parameters:

=over 4

=item text: The text to be sent to Side7::Utils::Text::parse_bbcode_markup

=back

    [% TextUtils.parse_bbcode_markup( text ) %]

=cut

sub parse_bbcode_markup
{
    my ( $self, $text ) = @_;

    return Side7::Utils::Text::parse_bbcode_markup( $text, {} );
}


=head2 filter_profanity()

Interface to Side7::Utils::Text::filter_profanity. Passes the text along to the function,
and returns its results.

Parameters:

=over 4

=item text: The text to be sent to Side7::Utils::Text::filter_profanity.

=back

    [% TextUtils.filter_profanity( text ) %]

=cut

sub filter_profanity
{
    my ( $self, $text ) = @_;

    return Side7::Utils::Text::filter_profanity( text => $text );
}


=head2 get_pronoun()

Interface to Side7::Utils::Text::get_pronoun. Passes the text along to the function,
and returns its results.

Parameters:

=over 4

=item sex: The User's sex to be sent to Side7::Utils::Text::get_pronoun. Defaults to the generic 'male', as per literary tradition.

=item pronoun_type: The pronoun type to use; The role of the pronoun. Accepts: 'subject', 'object', 'poss_determiner', 'poss_pronoun', 'reflexive'. Default: 'poss_pronoun'.

=back

    [% TextUtils.filter_profanity( user.sex, 'poss_pronoun' ) %]

=cut

sub get_pronoun
{
    my ( $self, $sex, $pronoun ) = @_;

    $sex     //= 'male';
    $pronoun //= 'poss_pronoun';

    return Side7::Utils::Text::get_pronoun( sex => $sex, part_of_speech => $pronoun );
}


=head2 sanitize_text_for_html()

Interface to Side7::Utils::Text::sanitize_text_for_html. Passes the text along to the function,
and returns its results.

Parameters:

=over 4

=item text: The text to be sent to Side7::Utils::Text::sanitize_text_for_html.

=back

    [% TextUtils.sanitize_text_for_html( text ) %]

=cut

sub sanitize_text_for_html
{
    my ( $self, $text ) = @_;

    return Side7::Utils::Text::sanitize_text_for_html( $text );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
