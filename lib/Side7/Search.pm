package Side7::Search;

use strict;
use warnings;

use Side7::Globals;
use Side7::User;
use Side7::User::Manager;
use Side7::UserContent::Image;
use Side7::UserContent::Image::Manager;

=pod


=head1 NAME

Side7::Search


=head1 DESCRIPTION

This package provides the search functionality for the site.

=cut


=head1 METHODS


=head2 new()

Creates a new search object.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $search = Side7::Search->new();

=cut

sub new
{
    my ( $class ) = @_;

    return bless {}, $class;
}


=head2 get_results()

Retrieve search results for a basic search term

Parameters:

=over 4

=item look_for: The search string.

=item page: The search page to hand back.

=back

    my $results = $search->get_results( 
                                        look_for => $search_string, 
                                        page     => $page,
                                        size     => $size,
                                        TODO: ADD IN ADDITIONAL ARGUMENTS FOR FILTERING
                                      );

=cut

sub get_results
{
    my ( $self, %args ) = @_;

    my $look_for = delete $args{'look_for'} // undef;
    my $page     = delete $args{'page'}     // 1;
    my $size     = delete $args{'size'}     // 'small';

    my @results = ();

    # Users
    my $users = Side7::Search::search_users( look_for => $look_for, page => $page, size => $size );
    $LOGGER->debug( 'Found users: ' . scalar( @{ $users } ) );
    my @sorted_users = sort { $a->{'username'} cmp $b->{'username'} } @{ $users };

    # Images
    my $images = Side7::Search::search_images( look_for => $look_for, page => $page, size => $size );
    $LOGGER->debug( 'Found images: ' . scalar( @{ $images } ) );

    # Literature

    # Music

    # Videos

    push( @results, @{ $images } );

    my @sorted_results = sort { 
                                $b->{'created_at'} cmp $a->{'created_at'} 
                                ||
                                $a->{'title'} cmp $b->{'title'}
                              } @results;

    unshift( @sorted_results, @sorted_users );

    return \@sorted_results;
}


=head1 FUNCTIONS


=head2 search_users()

Searches the Users for matching accounts.

Parameters:

=over 4

=item look_for: The search string.

=item page: The page number

=back

    my $users = Side7::Search::search_users( look_for => $look_for, page => $page );

=cut

sub search_users
{
    my ( %args ) = @_;

    my $look_for = delete $args{'look_for'} // undef;
    my $page     = delete $args{'page'}     // undef;

    my $users = Side7::User::Manager->get_users
    (
        query =>
        [
            username => { like => "%$look_for%" },
        ],
        with_objects => [ 'account' ],
    );

    my @results = ();

    foreach my $user ( @{ $users } )
    {
        my $user_hash = $user->get_user_hash_for_template();
        $user_hash->{'content_type'} = 'user';
        push( @results, $user_hash );
    }

    return \@results;
}


=head2 search_images()

Searches images for titles or descriptions containing the search string.

Parameters:

=over 4

=item look_for: The search string.

=item page: The page number of the search results to fetch.

=item size: The size of the thumbnails to return.

=back

    my $images = Side7::Search::search_images( look_for => $look_For, page => $page, size => $size );

=cut

sub search_images
{
    my ( %args ) = @_;
   
    my $look_for = delete $args{'look_for'} // undef;
    my $page     = delete $args{'page'}     // 1;
    my $size     = delete $args{'size'}     // 'small';

    my $images = Side7::UserContent::Image::Manager->get_images
    (
        query =>
        [
            or => 
            [
                title       => { like => "%$look_for%" },
                description => { like => "%$look_for%" },
            ],
        ],
        with_objects => [ 'rating', 'category', 'stage', 'user' ],
    );

    my @results = ();

    foreach my $image ( @{ $images } )
    {
        my $image_hash = $image->get_image_hash_for_template();
        $image_hash->{'content_type'} = 'image';

        my ( $filepath, $error ) = $image->get_image_path( size => $size );

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

        $image_hash->{'filepath'}       = $filepath;
        $image_hash->{'filepath_error'} = $error;
        $image_hash->{'uri'}            = "/image/$image->{'id'}";

        push @results, $image_hash;
    }

    return \@results;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
