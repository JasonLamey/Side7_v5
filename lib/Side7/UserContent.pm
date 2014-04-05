package Side7::UserContent;

use strict;
use warnings;

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

    my $gallery = Side7::UserContent::get_gallery( 
        $user_id, 
        { 
            sort_by => 'created_at DESC',
            TODO: DEFINE ADDITIONAL OPTIONAL ARGUMENTS
        }
    );

Fetches the User Content associated to a User, sorted and arranged in a way that matches any passed in parameters.

=cut

sub get_gallery
{
    my ( $user_id, $args ) = @_;

    my $sort_by = delete $args->{'sort_by'} // 'created_at DESC';

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
    
        push @results, $image_hash;
    }

    # TODO: Literature

    # TODO: Music

    # TODO: Videos

    return \@results;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
