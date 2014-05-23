package Side7::Utils::Image;

use strict;
use warnings;

use Image::Magick;
use GD;
use Image::Thumbnail;
use Const::Fast;
use Data::Dumper;

use Side7::Globals;
use Side7::Utils::File;

const my %IMAGEMAGICK_SIZE_LIMITS => (
                                        tiny   => '50x50',
                                        small  => '100x100',
                                        medium => '300x300',
                                        large  => '800x800',
                                     );

const my %GD_SIZE_LIMITS => (
                                tiny   => 50,
                                small  => 100,
                                medium => 300,
                                large  => 800,
                            );

=head1 NAME

Side7::Utils::Image


=head1 DESCRIPTION

This package provides utility functions for image manipulations.


=head1 FUNCTIONS


=head2 create_cached_image()

Creates an image file in one of the cached_file directories, depending upon the image_id, user_id, and image size.
Returns C<$success> as a boolean, and an error if C<$success> is false.

Parameters:

=over 4

=item image: Image object.

=item size: The size at which to create the image. Valid values are 'tiny', 'small', 'medium', 'large', 'original'. No default.

=item path: The file path in which to create the image. If not included, a new file path will be created.

=back

    my ( $success, $error ) = Side7::Utils::Image::create_cached_image( image => $image, size => $size, path => $path );

=cut

sub create_cached_image
{
    my ( %args ) = @_;

    my $image = delete $args{'image'} // undef;
    my $size  = delete $args{'size'}  // undef;
    my $path  = delete $args{'path'}  // undef;

    if ( ! defined $image )
    {
        $LOGGER->warn( 'Invalid Image object passed to create_cached_image.' );
        return( 0, 'Invalid Image for creating image.' );
    }

    if ( ! defined $size || $size eq '' )
    {
        $LOGGER->warn( 'Invalid size passed to create_cached_image.' );
        return( 0, 'Invalid size for creating image.' );
    }

    if ( ! defined $path || $path eq '' )
    {
        my ( $filepath, $error ) = $image->get_cached_image_path( size => $size );

        if ( ! defined $filepath || $filepath eq '' )
        {
            $LOGGER->warn( 'Invalid original Image path during create_cached_image: ' . $error );
            return( 0, 'Invalid path for creating image.' );
        }
        $path = $filepath;
    }

    my $user_gallery_path = $image->user->get_content_directory();

    my $input  = $user_gallery_path . $image->filename;

    my $original_image = Image::Magick->new();

    my ( $width, $height, $filesize, $format ) = $original_image->Ping( $input );

    if ( ! defined $format )
    {
        $LOGGER->warn( 'Cached file creation FAILED while getting properties of input file >' . $input . '<' );
        return( 0, 'A problem occurred while trying to create Image file.' );
    }

    # Set initial output size geometry.
    my $output_size = ( lc( $size ) eq 'original' ) ? $width . 'x' . $height : $IMAGEMAGICK_SIZE_LIMITS{$size};

    # Ensure we're not enlarging small images.  That would look nasty.
    if ( lc( $size ) ne 'original' )
    {
        my ( $limit_width, $limit_height ) = split( /x/, $IMAGEMAGICK_SIZE_LIMITS{$size} );

        if (
            $limit_width > $width
            &&
            $limit_height > $height
        )
        {
            $output_size = $width . 'x' . $height;
        }
    }

    # If the cached file doesn't exist, let's create it.
    if ( ! -f $path )
    {
        my $result = $original_image->Read($input);
        if ( $result )
        {
            $LOGGER->warn( 'Cached file creation FAILED while reading in >' . $input . '<: ' . $result );
            return( 0, 'A problem occurred while trying to create Image file.' );
        }

        if ( lc( $size ) ne 'original' )
        {
            $result = $original_image->Scale( geometry => $output_size );
            if ( $result )
            {
                $LOGGER->warn( 'Cached file creation FAILED while Thumbnailizing >' . $input . '<: ' . $result );
                return( 0, 'A problem occurred while trying to create Image file.' );
            }
        }

        $result = $original_image->Write( $path );
        if ( $result )
        {
            $LOGGER->warn( 'Cached file creation FAILED while saving image >' . $input . '<: ' . $result );
            return( 0, 'A problem occurred while trying to create Image file.' );
        }
    }

    return( 1, undef );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
