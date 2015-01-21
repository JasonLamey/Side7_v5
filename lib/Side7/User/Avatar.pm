package Side7::User::Avatar;

use strict;
use warnings;

use Gravatar::URL;

use Side7::Globals;

use Side7::UserContent;
use Side7::User::Avatar::UserAvatar;
use Side7::User::Avatar::UserAvatar::Manager;
use Side7::User::Avatar::SystemAvatar;

use version; our $VERSION = qv( '0.1.1' );

=pod


=head1 NAME

Side7::User::Avatar


=head1 DESCRIPTION

This module is the base module for the different Avatar models.


=head1 RELATIONSHIPS

=over

=item Side7::Account

Many to one relationship, depending upon the model.  user_id is the FK in all cases.

=back

=cut


=head1 METHODS


=head2 get_avatar()

Returns the URI to the appropariate avatar according to the User's settings.

Parameters:

=over 4

=item user: The User object, including the Account sub-object.

=item size: The Avatar size; accepts: 'tiny', 'small', 'medium', 'large', 'original'.  Defaults to 'small'.

=back

    my $avatar = Side7::User::Avatar->get_avatar( user => $user, size => $size );

=cut

sub get_avatar
{
    my ( $self, %args ) = @_;

    my $user = delete $args{'user'} // undef;
    my $size = delete $args{'size'} // 'small';

    # return Unknown User Icon if $user is undef
    if ( ! defined $user || ref( $user ) ne 'Side7::User' )
    {
        $LOGGER->warn( 'Invalid User object passed in when getting Avatar.' );
        return Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size );
    }

    my $avatar_type = $user->account->avatar_type() // 'None';

    my $avatar_uri = '';

    if ( $avatar_type eq 'System' )
    {
        $avatar_uri = Side7::User::Avatar::SystemAvatar->get_avatar_uri( avatar_id => $user->account->avatar_id(), size => $size );
    }
    elsif ( $avatar_type eq 'Image' )
    {
        $avatar_uri = Side7::User::Avatar::UserAvatar->get_avatar_uri( avatar_id => $user->account->avatar_id(), size => $size );
    }
    elsif ( $avatar_type eq 'Gravatar' )
    {
        my ( $gravatar_size, undef ) = split( /x/, $CONFIG->{'avatar'}->{'size'}->{$size} );
        my %options = (
                        size    => $gravatar_size,
                        rating  => 'r',
                        default => 'identicon',
                      );
        $avatar_uri = Gravatar::URL::gravatar_url( email => $user->email_address(), %options );
    }
    else
    {
        $avatar_uri = Side7::UserContent::get_default_thumbnail_path( type => 'default_avatar', size => $size );
    }

    $avatar_uri =~ s/^\/data//;
    return $avatar_uri;
}


=head1 FUNCTIONS


=head2 function_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package::function_name();

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
