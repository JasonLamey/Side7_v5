package Side7::Template::Plugin::DateTimeUtils;

=pod

=head1 NAME

Side7::Template::Plugin::DateTimeUtils

=head1 DESCRIPTION

This package is a Template::Toolkit plugin to give templates direct access to Side7::Utils::DateTime;

=cut

use base qw( Template::Plugin );

use strict;
use warnings;

use Template::Plugin;
use Data::Dumper;

use Side7::Globals;
use Side7::Utils::DateTime;


=head1 METHODS


=head2 new()

Instantiates a new C<DateTimeUtils> object for use by Template::Toolkit.

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

Interface to Side7::Utils::DateTime::format_ms_to_timestamp. Passes the text along to the function,
and returns its results.

Parameters:

=over 4

=item integer: The int to be sent to Side7::Utils::DateTime::format_ms_to_timestamp

=back

    [% DateTimeUtils.format_ms_to_timestamp( int ) %]

=cut

sub format_ms_to_timestamp
{
    my ( $self, $ms ) = @_;

    return Side7::Utils::DateTime::format_ms_to_timestamp( $ms, {} );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
