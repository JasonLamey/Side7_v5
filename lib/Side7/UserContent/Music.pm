package Side7::UserContent::Music;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use DateTime;
use Data::Dumper;

use Side7::Globals;
use Side7::UserContent;
use Side7::UserContent::Music::DailyView::Manager;
use Side7::UserContent::Music::DetailedView::Manager;
use Side7::UserContent::Comment;
use Side7::Utils::File;
use Side7::Utils::Text;
#use Side7::Utils::Audio; # TODO: COMING SOON.

use version; our $VERSION = qv( '0.1.0' );

=pod


=head1 NAME

Side7::UserContent::Music


=head1 DESCRIPTION

This class represents music-based User Content.


=head1 SCHEMA INFORMATION

    Table name: music

    | id             | int(10) unsigned                        | NO   | PRI | NULL    | auto_increment |
    | user_id        | int(8) unsigned                         | NO   | MUL | NULL    |                |
    | filename       | varchar(255)                            | NO   |     | NULL    |                |
    | filesize       | int(9) unsigned                         | YES  |     | NULL    |                |
    | title          | varchar(255)                            | NO   |     | NULL    |                |
    | description    | text                                    | YES  |     | NULL    |                |
    | transcript     | text                                    | YES  |     | NULL    |                |
    | encoding       | varchar(45)                             | NO   |     | NULL    |                |
    | bitrate        | varchar(45)                             | NO   |     | NULL    |                |
    | sample_rate    | varchar(45)                             | NO   |     | NULL    |                |
    | length         | varchar(45)                             | NO   |     | NULL    |                |
    | category_id    | int(8) unsigned                         | NO   | MUL | NULL    |                |
    | rating_id      | int(8) unsigned                         | NO   | MUL | NULL    |                |
    | stage_id       | int(5) unsigned                         | NO   | MUL | NULL    |                |
    | privacy        | enum('Public','Friends Only','Private') | NO   |     | Public  |                |
    | is_archived    | tinyint(1)                              | NO   | MUL | 0       |                |
    | copyright_year | int(4)                                  | NO   |     | NULL    |                |
    | content_type   | varchar(15)                             | NO   |     | music   |                |
    | created_at     | datetime                                | NO   |     | NULL    |                |
    | updated_at     | datetime                                | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Class::Name

TODO: Define the relationship type, and list the foreign key (FK).

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'music',
    columns => [
        id             => { type => 'serial',  not_null => 1 },
        user_id        => { type => 'integer', not_null => 1 },
        filename       => { type => 'varchar', length => 255, not_null => 1 },
        filesize       => { type => 'integer', not_null => 1 },
        title          => { type => 'varchar', length => 255, not_null => 1 },
        description    => { type => 'text' },
        transcript     => { type => 'text' },
        encoding       => { type => 'varchar', length => 45,  not_null => 1 },
        bitrate        => { type => 'integer', not_null => 1 }, # In bps
        sample_rate    => { type => 'integer', not_null => 1 }, # In kHz
        length         => { type => 'integer', not_null => 1 }, # In msec
        category_id    => { type => 'integer', not_null => 1 },
        rating_id      => { type => 'integer', not_null => 1 },
        stage_id       => { type => 'integer', not_null => 1 },
        privacy        => {
                            type     => 'enum',
                            values   => [ 'Public', 'Friends Only', 'Private' ],
                            not_null => 1,
                            default  => 'Public',
                          },
        is_archived    => { type => 'integer', not_null => 1 },
        copyright_year => { type => 'integer', default => 'NULL' },
        checksum       => { type => 'varchar', length => 120 },
        content_type   => { type => 'varchar', length => 15, default => 'Music' },
        created_at     => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at     => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    foreign_keys =>
    [
        daily_views =>
        {
            class       => 'Side7::UserContent::Music::DailyView',
            key_columns => { id => 'music_id' },
            type        => 'one to many',
        },
        detailed_views =>
        {
            class       => 'Side7::UserContent::Music::DetailedView',
            key_columns => { id => 'music_id' },
            type        => 'one to many',
        },
        user =>
        {
            class       => 'Side7::User',
            key_columns => { user_id => 'id' },
        },
        category =>
        {
            class       => 'Side7::UserContent::Category',
            key_columns => { category_id => 'id' },
        },
        rating =>
        {
            class       => 'Side7::UserContent::Rating',
            key_columns => { rating_id => 'id' },
        },
        stage =>
        {
            class       => 'Side7::UserContent::Stage',
            key_columns => { stage_id => 'id' },
        },
    ],
    relationships =>
    [
        albums =>
        {
            type        => 'many to many',
            map_class   => 'Side7::UserContent::AlbumMusicMap',
        },
        comment_threads =>
        {
            type        => 'one to many',
            class       => 'Side7::UserContent::CommentThread',
            key_columns => { id => 'content_id', content_type => 'content_type' },
        },
    ],
);


=head1 METHODS


=head2 get_cached_music_path()

Returns the path to the cached music file to be used to play back the file.

Parameters:

=over 4

=item None.

=back

    my ( $music_path, $error ) = $music->get_cached_music_path();

=cut

sub get_cached_music_path
{
    my ( $self, %args ) = @_;

    return if ! defined $self;

}


=head2 get_enum_values()

Returns a hash ref of arrays of enum values for each related field for a Music.

Parameters: None.

    my $enums = Side7::UserContent::Music->get_enum_values();

=cut

sub get_enum_values
{
    my $self = shift;

    my $enums = {};

    my $music_enums = Side7::DB::get_enum_values_for_form( fields => [ 'privacy' ], table => 'music' );

    $enums = ( $music_enums ); # Merging returned enum hash refs into one hash ref.

    return $enums;
}


=head2 show_music( music_id => $music_id )

Returns an music hash ref for the requested music, for the display page.

Parameters:

=over 4

=item music_id: The ID of the music to be displayed.

=back

    my $music_hash = Side7::UserContent::Music->show_music( music_id => $music_id );

=cut

sub show_music
{
    my ( $self, %args ) = @_;

    my $music_id         = delete $args{'music_id'};
    my $request          = delete $args{'request'}          // undef;
    my $session          = delete $args{'session'}          // undef;
    my $filter_profanity = delete $args{'filter_profanity'} // 1;

    return {} if ( ! defined $music_id || $music_id =~ m/\D+/ || $music_id eq '' );

    my $music = Side7::UserContent::Music->new( id => $music_id );
    my $loaded = $music->load(
                                speculative => 1,
                                with =>
                                [
                                    'user',
                                    'stage',
                                    'rating',
                                    'category',
                                    #'properties',
                                    'comment_threads',
                                    'comment_threads.comments',
                                ]
    );

    # Music Not Found
    if (
        $loaded == 0
        ||
        ! defined $music
    )
    {
        $LOGGER->warn( 'Could not find music with ID >' . $music_id . '< in database.' );
        return {};
    }

    # Music Found
    my $music_hash = {};
    $music_hash->{'content'} = $music;

    my $filtered_data = {};

    # BBCode Parsing
    foreach my $key ( qw/ description / )
    {
        $filtered_data->{$key} = Side7::Utils::Text::parse_bbcode_markup( $music->$key, {} );
    }

    $filtered_data->{'filesize'} =
                Side7::Utils::File::get_formatted_filesize_from_bytes( bytes => $music->filesize );

    # Filter profanity
    if ( $filter_profanity == 1 )
    {
        foreach my $key ( qw/ title description transcript / )
        {
            my $text = ( exists $filtered_data->{$key} ) ? $filtered_data->{$key} : $music->$key;
            $filtered_data->{$key} = Side7::Utils::Text::filter_profanity( text => $text );
        }
    }

    # Music Rating Stylizing and Qualifiers
    $filtered_data->{'rating'} = $music->rating->rating;

    # Fetch Music Comments
    my $music_comments =
        Side7::UserContent::CommentThread::get_all_comments_for_content(
                                                                        content_type => ucfirst( $music->content_type ),
                                                                        content_id   => $music_id
                                                                       ) // [];
    $music_hash->{'comment_threads'} = $music_comments if defined $music_comments;

    # Music Thumbnail Filepath
#    my ( $filepath, $error ) = $image->get_cached_image_path( size => $size );
#    if ( defined $error && $error ne '' )
#    {
#        $LOGGER->warn( $error );
#        $image_hash->{'filepath_error'} = $error;
#    }
#    else
#    {
#        if ( ! -f $filepath )
#        {
#            my ( $success, $error ) = $image->create_cached_file( size => $size, path => $filepath );
#
#            if ( ! $success )
#            {
#                $LOGGER->warn( $error );
#                $image_hash->{'filepath_error'} = $error;
#                $image_hash->{'filepath'}       = Side7::UserContent::get_default_thumbnail_path(
#                                                                                                    type => 'default_image',
#                                                                                                    size => $size,
#                                                                                                );
#            }
#            else {
#                $filepath =~ s/^\/data//;
#                $image_hash->{'filepath'} = $filepath;
#            }
#        }
#        else
#        {
#            $filepath =~ s/^\/data//;
#            $image_hash->{'filepath'} = $filepath;
#        }
#    }
#
    # Add a new view
    ### Increase Daily View counter.
    my $daily_updated = Side7::UserContent::Music::DailyView::update_daily_views( music_id => $music_id );

    if ( ! defined $daily_updated )
    {
        $LOGGER->warn( 'Could not update daily view count for Music ID: >' . $music_id . '<.' );
    }

    ### Insert new Detailed View record, including date, IP info, user agent info, and referrer info.
    my $detailed_updated = Side7::UserContent::Music::DetailedView::add_detailed_view(
                                                                                        music_id => $music_id,
                                                                                        request  => $request,
                                                                                        session  => $session,
                                                                                     );

    if ( ! defined $detailed_updated )
    {
        $LOGGER->warn( 'Could not update detailed view for Music ID: >' . $music_id . '<.' );
    }

    # Get total views
    $music_hash->{'total_views'} =
        Side7::UserContent::Music::DailyView::get_total_views_count( music_id => $music_id ) // 0;

    $music_hash->{'filtered_content'} = $filtered_data;

    return $music_hash;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
