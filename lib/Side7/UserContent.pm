package Side7::UserContent;

use strict;
use warnings;

use Dancer qw( :script );
use Data::Dumper;

use Side7::Globals;
use Side7::UserContent::Image;
use Side7::UserContent::Image::Manager;

=pod

=head1 NAME

Side7::UserContent

=head1 DESCRIPTION

This package represents a User's uplaoded Content. It provides the methods
and functions for manipulating the content of the displayed gallery, such as sort order, category views, etc.

=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Image::Manager

Side7::Gallery will call Image objects for display.

=back

=cut


=head1 METHODS


=head2 method_name

    $result = My::Package->method_name();

TODO: Define what this method does, describing both input and output values and types.

=cut


=head1 FUNCTIONS


=head2 get_gallery()

Fetches the User Content associated to a User, sorted and arranged in a way that matches any passed in parameters.

Parameters:

=over 4

=item session: The visitor's session for User Preference controls/filtering.  Defaults to undef.

=item sort_by: Custom sort-by routine. Defaults to 'created_at DESC'.

=item size: Thumbnail size; defaults to 'small'.

=back

    my $gallery = Side7::UserContent::get_gallery( 
        $user_id, 
        { 
            session => $session,
            sort_by => 'created_at DESC',
            TODO: DEFINE ADDITIONAL OPTIONAL ARGUMENTS
        }
    );

=cut

sub get_gallery
{
    my ( $user_id, $args ) = @_;

    my $sort_by = delete $args->{'sort_by'} // 'created_at DESC';
    my $size    = delete $args->{'size'}    // 'small';
    my $session = delete $args->{'session'} // undef;

    if ( ! defined $user_id || $user_id !~ m/^\d+$/) 
    {
        $LOGGER->warn( 'Invalid User ID >' . $user_id . '< when attempting to fetch gallery contents.' );
        return [];
    }

    my @results;

    # Images
    my $images = Side7::UserContent::Image::Manager->get_images
    (
        query =>
        [
            user_id => [ $user_id ],
        ],
        with_objects => [ 'rating', 'category', 'stage' ],
        sort_by      => $sort_by,
    );

    foreach my $image ( @$images )
    {
        my $image_hash = $image->get_image_hash_for_template();
        $image_hash->{'content_type'} = 'image';

        my ( $filepath, $error );
 
        if ( $image->block_thumbnail( session => $session ) == 1 )
        {
            $filepath = Side7::UserContent::get_default_thumbnail_path( type => 'blocked_image', size => $size );
            $error = 'Either you are not logged in, or you have selected to block rated M image thumbnails.';
        }
        else
        {

            ( $filepath, $error ) = $image->get_cached_image_path( size => $size );

            if ( defined $error && $error ne '' )
            {
                $LOGGER->warn( $error );
            }
            else
            {
                if ( ! -f $filepath )
                {
                    my ( $success, $error ) = $image->create_cached_file( size => $size );

                    if ( $success )
                    {
                        $filepath =~ s/^\/data//;
                    }
                }
                else
                {
                    $filepath =~ s/^\/data//;
                }
            }
        }

        $image_hash->{'filepath'}       = $filepath;
        $image_hash->{'filepath_error'} = $error;
        $image_hash->{'uri'}            = "/image/$image->{'id'}";

        push @results, $image_hash;
    }

    # TODO: Literature

    # TODO: Music

    # TODO: Videos

    return \@results;
}


=head2 get_default_thumbnail_path()

Returns a path for a default image in the event of a missing or unloadable User Content thumbnail.

Parameters:

=over 4

=item type: Determines the type of image to show: 'broken_image', 'blocked_image', 'default_image', 'default_music', 'default_literature'. Required, no default.

=item size: The thumbnail size being requested: 'tiny', 'small', 'medium', 'large', 'original'. Required, defaults to 'original'

=back

    my $path = Side7::UserContent::get_default_thumbnail_path( type => $type, size => $size );

=cut

sub get_default_thumbnail_path
{
    my ( %args ) = @_;

    my $type = delete $args{'type'} // return undef;
    my $size = delete $args{'size'} // 'original';

    my $path = $CONFIG->{'image'}->{'default_thumb_path'};
   
    $path =~ s/:::SIZE:::/$size/g;
    $path =~ s/:::TYPE:::/$type/g;

    return lc( $path );
}


=head2 get_enums_for_form()

Retrieves the enum values for the appropriate fields for the content type. Returns a hash ref of arrays.

Parameters:

=over 4

=item content_type: The content type to retrieve enum values to return. Takes 'image', 'music', 'literature'.

=back

    my $enums = Side7::UserContent::get_enums_for_form( content_type => $content_type );

=cut

sub get_enums_for_form
{
    my ( %args ) = @_;

    my $content_type = delete $args{'content_type'} // undef;

    return {} if ! defined $content_type;

    my $enums = ();
    if ( lc( $content_type ) eq 'image' )
    {
        $enums = Side7::UserContent::Image->get_enum_values();
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
    }
    elsif ( lc( $content_type ) eq 'video' )
    {
    }

    # TODO: ADD IN CHECKS FOR MUSIC AND LITERATURE.

    return $enums;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
