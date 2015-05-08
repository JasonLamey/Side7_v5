package Side7::Search;

use strict;
use warnings;

use Data::Dumper;
use DateTime;
use Try::Tiny;
use YAML::Syck;
$YAML::Syck::ImplicitUnicode = 1;

use Side7::Globals;
use Side7::Search::History;
use Side7::Search::History::Manager;
use Side7::User;
use Side7::User::Manager;
use Side7::UserContent;
use Side7::UserContent::Image;
use Side7::UserContent::Image::Manager;
use Side7::UserContent::Music;
use Side7::UserContent::Music::Manager;
use Side7::Utils::Crypt;

use version; our $VERSION = qv( '0.1.7' );

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

=item filter_profanity: Boolean to deterimine if profanity should be filtered out.

=back

    my $results = $search->get_results(
                                        look_for         => $search_string,
                                        page             => $page,
                                        size             => $size,
                                        filter_profanity => $filter_profanity,
                                        TODO: ADD IN ADDITIONAL ARGUMENTS FOR FILTERING
                                      );

=cut

sub get_results
{
    my ( $self, %args ) = @_;

    my $look_for         = delete $args{'look_for'}         // undef;
    my $page             = delete $args{'page'}             // 1;
    my $size             = delete $args{'size'}             // 'small';
    my $filter_profanity = delete $args{'filter_profanity'} // 1;

    # Search Term Validation:
    if ( ! defined $look_for || $look_for eq '' )
    {
        return ( [], 'Invalid search term: You need to provide at least one word of at least 3 characters in length.' );
    }

    if ( length( $look_for ) < 3 )
    {
        return ( [], 'Invalid search term: You need to provide at least one word of at least 3 characters in length.' );
    }

    my @results = ();

    # Check Side7::Search::History to see if this same search has been done within the past 30 minutes.
    # If so, let's pull the cached results instead of re-searching.
    my $history = Side7::Search::get_history( search_term => $look_for ) // [];
    if ( defined $history && scalar( @{ $history } ) > 0 )
    {
        return $history;
    }

    # Users
    my $users = Side7::Search::search_users(
                                            look_for         => $look_for,
                                            page             => $page,
                                            size             => $size,
                                            filter_profanity => $filter_profanity,
                                           );
    my @sorted_users = sort { lc( $a->{'user'}->username ) cmp lc( $b->{'user'}->username ) } @{ $users };

    # Images
    my $images = Side7::Search::search_images(
                                                look_for         => $look_for,
                                                page             => $page,
                                                size             => $size,
                                                filter_profanity => $filter_profanity,
                                             );
    push( @results, @{ $images } );

    # Literature

    # Music

    # Videos

    my @sorted_results = sort {
                                $b->{'content'}->created_at cmp $a->{'content'}->created_at
                                ||
                                $a->{'content'}->title      cmp $b->{'content'}->title
                              } @results;

    unshift( @sorted_results, @sorted_users );

    # Before returning the sorted results, let's cache them for future reference.
    my $now             = DateTime->now();
    my $filename        = Side7::Utils::Crypt::md5_hex_encode( $look_for . $now ) . '.yml';
    my $results_file    = new IO::File( $CONFIG->{'search'}->{'history_path'} . $filename, ">:encoding( UTF-8 )" );
    if ( defined $results_file )
    {
        YAML::Syck::DumpFile( $results_file, \@sorted_results );
        undef $results_file;
    }
    else
    {
        $LOGGER->warn( 'Could not write search history file for >' . $look_for . '<: ' . $! );
    }
    my $search_history  = Side7::Search::History->new(
                                                        search_term  => $look_for,
                                                        timestamp    => $now,
                                                        user_id      => undef,
                                                        ip_address   => undef,
                                                        results      => $filename,
                                                        search_count => 1,
                                                     );
    $search_history->save();

    return ( \@sorted_results, undef );
}


=head1 FUNCTIONS


=head2 get_history()

Searches the Search History for any similar searches within the last 30 minutes.

Parameters:

=over 4

=item search_term: The search string.

=back

    my $history = Side7::Search::get_history( search_term => $look_for );

=cut

sub get_history
{
    my ( %args ) = @_;

    my $search_term = delete $args{'search_term'} // return [];

    my $now_string = DateTime->now()->strftime( '%F %R' );
    my $searches = Side7::Search::History::Manager->get_searches
    (
        query =>
        [
            search_term => $search_term,
            \"TIMESTAMPDIFF(MINUTE, timestamp, '$now_string') <= 30",
        ],
        sort_by => 'timestamp DESC',
        limit => 1,
        query_is_sql => 1,
    );

    if ( ! defined $searches )
    {
        return [];
    }

    my @history      = ();
    my $results_file = '';
    if
    (
        defined $searches->[0]->{'results'}
        &&
        $searches->[0]->{'results'} ne ''
    )
    {
        $results_file = $CONFIG->{'search'}->{'history_path'} . $searches->[0]->{'results'};
        @history = @{ YAML::Syck::LoadFile( $results_file ) };
        #$LOGGER->debug( 'HISTORY: ' . Dumper( \@history ) );
    }

    # Update the count on the history record.
    if ( defined $results_file && $results_file ne '' )
    {
        my $updated = 0;
        try
        {
            $updated = Side7::Search::History::Manager->update_searches
            (
                set =>
                {
                    search_count => { sql => 'search_count + 1' },
                },
                where =>
                [
                    id => $searches->[0]->{'id'},
                ],
            );
        }
        catch
        {
            $LOGGER->warn(
                            'Search count update FAILED for search ID: >' .
                            $searches->[0]->{'id'} .
                            '<, term: >' .
                            $searches->[0]->{'search_term'} .
                            '<: ' . $_
                         );
        };

        if ( $updated != 1 )
        {
            $LOGGER->warn(
                            'Search count not updated for search ID: >' .
                            $searches->[0]->{'id'} .
                            '<, term: >' .
                            $searches->[0]->{'search_term'} .
                            '<'
                         );
        }
    }

    return \@history;
}


=head2 search_users()

Searches the Users for matching accounts.

Parameters:

=over 4

=item look_for: The search string.

=item page: The page number

=item filter_profanity: Boolean to indicate if profanity should be filtered out. Defaults to 1.

=back

    my $users = Side7::Search::search_users( look_for => $look_for, page => $page );

=cut

sub search_users
{
    my ( %args ) = @_;

    my $look_for         = delete $args{'look_for'}         // undef;
    my $page             = delete $args{'page'}             // undef;
    my $filter_profanity = delete $args{'filter_profanity'} // 1;

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
        my $user_hash = {};
        $user_hash->{'user'}                      = $user;
        $user_hash->{'content'}->{'content_type'} = 'user';

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

=item filter_profanity: Boolean to indicate if profanity should be filtered out. Defaults to 1.

=back

    my $images = Side7::Search::search_images( look_for => $look_for, page => $page, size => $size );

=cut

sub search_images
{
    my ( %args ) = @_;

    my $look_for         = delete $args{'look_for'}         // undef;
    my $page             = delete $args{'page'}             // 1;
    my $size             = delete $args{'size'}             // 'small';
    my $filter_profanity = delete $args{'filter_profanity'} // 1;

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

    my $formatted_results =
        Side7::UserContent->get_image_hash_for_resultset( images => $images, size => $size, session => undef );

    #$LOGGER->debug( 'FORMATTED RESULTS: ' . Dumper( $formatted_results ) );

    return $formatted_results;
}


=head2 highlight_match()

Returns the passed-in text, with the matching words wrapped in spanned highlight code.

Parameters:

=over 4

=item text: The text to find matches within.

=item look_for: The text to match against.

=back

    my $highlighted_text = Side7::Search::highlight_match( text => $text, look_for => $look_for );

=cut

sub highlight_match
{
    my ( %args ) = @_;

    my $text     = delete $args{'text'}     // undef;
    my $look_for = delete $args{'look_for'} // undef;

    return ''    if ! defined $text;
    return $text if ! defined $look_for;

    ( my $highlighted_text = $text ) =~ s/($look_for)/<span style="background-color: #FFFF80;">$1<\/span>/gi;

    return $highlighted_text;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
