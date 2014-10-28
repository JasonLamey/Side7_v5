package Side7::Template::Plugin::Search;

=pod

=head1 NAME

Side7::Template::Plugin::Search

=head1 DESCRIPTION

This package is a Template::Toolkit plugin to give templates direct access to Side7::Search;

=cut

use base qw( Template::Plugin );

use strict;
use warnings;

use Template::Plugin;
use Data::Dumper;

use Side7::Globals;
use Side7::Search;


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


=head2 highlight_match()

Interface to Side7::Search::highlight_match. Passes the text along to the function,
and returns its results.

    my $highlighted_text = Side7::Search::highlight_match( text => $text, look_for => $look_for );

Parameters:

=over 4

=item text: The text to be sent to Side7::Search::highlight_match

=item look_for: The text to be matched against

=back

    [% Search.highlight_match( text, look_for ) %]

=cut

sub highlight_match
{
    my ( $self, $text, $look_for ) = @_;

    return Side7::Search::highlight_match( text => $text, look_for => $look_for );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
