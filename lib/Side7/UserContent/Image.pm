package Side7::UserContent::Image;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use DateTime;
use Data::Dumper;

use Side7::Globals;
use Side7::UserContent;
use Side7::UserContent::Image::DailyView::Manager;
use Side7::UserContent::Image::DetailedView::Manager;
use Side7::UserContent::Comment;
use Side7::Utils::File;
use Side7::Utils::Text;
use Side7::Utils::Image;

use version; our $VERSION = qv( '0.1.18' );

=pod


=head1 NAME

Side7::UserContent::Image


=head1 DESCRIPTION

This package represents an Image object as uploaded by a User.


=head1 SCHEMA INFORMATION

    Table name: images

    id                :integer          not null, primary key
    user_id           :int(8)           not null
    filename          :string(255)      not null
    title             :string(255)      not null
    filesize          :bigint(20)       not null
    dimensions        :string(15)       not null
    category_id       :int(8)           not null
    rating_id         :int(8)           not null
    rating_qualifiers :string(10)
    stage_id          :int(8)           not null
    description       :text(16)
    privacy           :enum             not null
    is_archived       :int(1)           not null
    copyright_year    :int(4)
    checksum          :varchar(120)
    content_type      :varchar(5)       not null, 'Image'
    created_at        :datetime         not null
    updated_at        :datetime         not null


=head1 RELATIONSHIPS

=over

=item Side7::User

Many to one relationship with Side7::User, using user_id as a foreign key.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'images',
    columns => [
        id                => { type => 'serial', primary_key => 1, not_null => 1 },
        user_id           => { type => 'integer', length => 8,   not_null => 1 },
        filename          => { type => 'varchar', length => 255, not_null => 1 },
        title             => { type => 'varchar', length => 255, not_null => 1 },
        filesize          => { type => 'integer', length => 20,  not_null => 1 },
        dimensions        => { type => 'varchar', length => 15,  not_null => 1 },
        category_id       => { type => 'integer', length => 8,   not_null => 1 },
        rating_id         => { type => 'integer', length => 8,   not_null => 1 },
        rating_qualifiers => { type => 'varchar', length => 10 },
        stage_id          => { type => 'integer', length => 5,   not_null => 1 },
        description       => { type => 'text',                                  default => 'null' },
        privacy           => {
                               type    => 'enum',
                               values  => [ 'Public', 'Friends Only', 'Private' ],
                               default => 'Public'
        },
        is_archived       => { type => 'integer', length => 1,   not_null => 1, default => 0 },
        copyright_year    => { type => 'integer', length => 4 },
        checksum          => { type => 'varchar', length => 120 },
        content_type      => { type => 'varchar', length => 5, default => 'Image' },
        created_at        => { type => 'datetime',               not_null => 1, default => 'now()' },
        updated_at        => { type => 'datetime',               not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'user_id' ], [ 'filename' ], [ 'title' ] ],
    foreign_keys =>
    [
        user =>
        {
            class       => 'Side7::User',
            key_columns => { user_id => 'id' },
        },
        rating =>
        {
            class       => 'Side7::UserContent::Rating',
            key_columns => { rating_id => 'id' },
        },
        category =>
        {
            class       => 'Side7::UserContent::Category',
            key_columns => { category_id => 'id' },
        },
        stage =>
        {
            class       => 'Side7::UserContent::Stage',
            key_columns => { stage_id => 'id' },
        },
    ],
    relationships =>
    [
        daily_views =>
        {
            class       => 'Side7::UserContent::Image::DailyView',
            key_columns => { id => 'image_id' },
            type        => 'one to many',
        },
        detailed_views =>
        {
            class       => 'Side7::UserContent::Image::DetailedView',
            key_columns => { id => 'image_id' },
            type        => 'one to many',
        },
        properties =>
        {
            class       => 'Side7::UserContent::Image::Property',
            key_columns => { id => 'image_id' },
            type        => 'one to many',
        },
        comment_threads =>
        {
            class       => 'Side7::UserContent::CommentThread',
            key_columns => { id => 'content_id' },
            type        => 'one to many',
        },
        albums =>
        {
            type        => 'many to many',
            map_class   => 'Side7::UserContent::AlbumImageMap',
        },
    ],
);


=head1 METHODS


=head2 get_cached_image_path()

Returns the path to the cached image file to be used to display the image.

Parameters:

=over 4

=item size: The image size to return. Valid values are 'tiny', 'small', 'medium', 'large', 'original'. Default is 'original'.

=back

    my ( $image_path, $error ) = $image->get_cached_image_path( size => $size );

=cut

sub get_cached_image_path
{
    my ( $self, %args ) = @_;

    return if ! defined $self;

    my $size = delete $args{'size'} // 'original';

    my ( $success, $error, $image_path ) =
            Side7::Utils::File::create_user_cached_file_directory(
                                                                    user_id      => $self->user_id,
                                                                    content_type => 'images',
                                                                    content_size => $size
                                                                 );

    if ( ! $success )
    {
        return (
                    Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size ),
                    $error
               );
    }

    my $user_gallery_path = $self->user->get_content_directory();

    my $original_image = Image::Magick->new();

    my ( $width, $height, $filesize, $format ) = $original_image->Ping( $user_gallery_path . $self->filename );

    if ( ! defined $format )
    {
        $LOGGER->warn( 'Getting image path FAILED while getting properties of input file >' . $user_gallery_path . $self->filename . '<' );
        return(
                Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size ),
                'A problem occurred while trying to get Image file.'
              );
    }

    my $extension = '';
    if ( $format eq 'JPEG' )
    {
        $extension = '.jpg';
    }
    elsif ( $format eq 'GIF' )
    {
        $extension = '.gif';
    }
    elsif ( $format eq 'PNG' )
    {
        $extension = '.png';
    }
    else
    {
        return(
                Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size ),
                'Invalid image file type.'
              );
    }

    my $filename = $self->id . $extension;

    return ( $image_path . '/' . $filename, undef );
}


=head2 get_image_hash_for_template()

Takes Image object and converts it into an easily accessible hash to pass to the templates.  Additionally, it formats the associated dates and other data properly for output.

Parameters:

=over 4

=item filter_profanity: Boolean value, whether to filter out profanity. Defaults to 1.

=back

    my $image_hash = $image->get_image_hash_for_template( filter_profanity => $filter_profanity );

=cut

sub get_image_hash_for_template
{
    my ( $self, %args ) = @_;

    return {} if ! defined $self;

    my $filter_profanity = delete $args{'filter_profanity'} // 1;

    my $image_hash = {};

    # Image values
    foreach my $key (
        qw( id user_id filename title dimensions category_id rating_id
            rating_qualifiers stage_id privacy is_archived
            copyright_year )
    )
    {
        $image_hash->{$key} = $self->$key;
    }

    # Description
    $image_hash->{'description'} = Side7::Utils::Text::parse_bbcode_markup( $self->description );

    # Filesize
    $image_hash->{'filesize'} = Side7::Utils::File::get_formatted_filesize_from_bytes( bytes => $self->filesize );

    # Date values
    foreach my $key ( qw( created_at updated_at ) )
    {
        my $date       = $self->$key( format => '%A, %c' );
        my $epoch_date = $self->$key( format => '%s' );
        $date       =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
        $epoch_date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
        $image_hash->{$key} = $date;
        $image_hash->{$key . '_epoch'} = $epoch_date;
    }

    # User values:
    my $user = $self->{'user'};
    if ( defined $user )
    {
        foreach my $key ( qw( username ) )
        {
            $image_hash->{'user'}->{$key} = $user->$key;
        }
        $image_hash->{'user'}->{'user_directory'} = $user->get_content_directory();
        $image_hash->{'user'}->{'user_uri'}       = $user->get_content_uri();
    }

    # Rating values:
    my $rating = $self->{'rating'};
    $image_hash->{'rating_text'} = $rating->rating;
    if ( defined $self->rating_qualifiers and $self->rating_qualifiers ne '' )
    {
        $image_hash->{'rating_text'} .= ' (' . $self->rating_qualifiers . ')';
    }

    # Category values:
    my $category = $self->{'category'};
    $image_hash->{'category_text'} = $category->category;

    # Stage values:
    my $stage = $self->{'stage'};
    $image_hash->{'stage_text'} = $stage->stage;

    # Filter Profanity
    if ( $filter_profanity == 1 )
    {
        foreach my $key ( qw/ title description / )
        {
            $image_hash->{$key} = Side7::Utils::Text::filter_profanity( text => $image_hash->{$key} );
        }
    }

    return $image_hash;
}


=head2 create_cached_file()

Creates a copy of the original file in the appropriate cached_file directory if it doesn't exist. Returns success or error.
Returns success if already existent.

Parameters:

=over 4

=item size: The image size. Valid values are 'tiny', 'small', 'medium', 'large', 'original'

=back

    my ( $success, $error ) = $image->create_cached_file( size => $size );

=cut

sub create_cached_file
{
    my ( $self, %args ) = @_;

    return ( 0, 'Invalid Image Object' ) if ! defined $self;

    my $size = delete $args{'size'} // undef;
    my $path = delete $args{'path'} // undef;

    if ( ! defined $size )
    {
        return ( 0, 'Invalid image size passed.' );
    }

    if ( ! defined $path || $path eq '' )
    {
        $path = $self->get_cached_image_path( size => $size );
    }

    my ( $success, $error ) = Side7::Utils::Image::create_cached_image( image => $self, size => $size, path => $path );

    if ( ! defined $success )
    {
        $LOGGER->warn( "Could not create cached image file for >$self->filename<, ID: >$self->id<: $error" );
        return ( 0, 'Could not create cached image.' );
    }

    return ( $success, undef );
}


=head2 get_enum_values()

Returns a hash ref of arrays of enum values for each related field for an Image.

Parameters: None.

    my $enums = Side7::UserContent::Image->get_enum_values();

=cut

sub get_enum_values
{
    my $self = shift;

    my $enums = {};

    my $image_enums = Side7::DB::get_enum_values_for_form( fields => [ 'privacy' ], table => 'images' );

    $enums = ( $image_enums ); # Merging returned enum hash refs into one hash ref.

    return $enums;
}


=head2 block_thumbnail()

Returns a boolean value to indicate if the image thumbnail should be blocked for the viewer or not, based on
the image's rating, the logged-in status of the User, and the User's Preferences.

Parameters: None.

    my $block = $image->block_thumbnail();

=cut

sub block_thumbnail
{
    my ( $self, %args ) = @_;

    my $session = $args{'session'} // {};

    my $logged_in = ( defined $session->{'logged_in'} && $session->{'logged_in'} == 1 ) ? 1 : 0;

    # Don't block the image if the rating isn't 'M'.
    if ( $self->{'rating'}->{'rating'} ne 'M' )
    {
        return 0;
    }

    # Do block the image if the rating is 'M' and the User isn't logged in.
    if ( $logged_in == 0 )
    {
        return 1;
    }

    my $visitor = Side7::User->new( id => $session->{'user_id'} );
    my $vis_loaded = $visitor->load( speculative => 1, with => [ 'user_preferences' ] );

    # If the session contains invalid data, block the image.
    if ( $vis_loaded == 0 )
    {
        return 1;
    }

    # Don't block the image if the rating is 'M', the User is logged in, and the Preference is not to block.
    if ( $visitor->user_preferences->show_m_thumbs == 1 )
    {
        return 0;
    }

    # Fall-through: Do block the image.
    return 1;
}


=head1 FUNCTIONS


=head2 show_image()

Returns an image hash ref for the requested image, for the display page.

Parameters:

=over 4

=item image_id: The ID of the image to be displayed.

=item size: The image size to show: 'tiny', 'small', 'medium', 'large', 'orginal'.

=back

    my $image_hash = Side7::UserContent::Image::show_image( image_id => $image_id, size => $size );

=cut

sub show_image
{
    my ( %args ) = @_;

    my $image_id         = delete $args{'image_id'};
    my $request          = delete $args{'request'}          // undef;
    my $session          = delete $args{'session'}          // undef;
    my $size             = delete $args{'size'}             // 'original';
    my $filter_profanity = delete $args{'filter_profanity'} // 1;

    return {} if ( ! defined $image_id || $image_id =~ m/\D+/ || $image_id eq '' );

    my $image = Side7::UserContent::Image->new( id => $image_id );
    my $loaded = $image->load(
                                speculative => 1,
                                with =>
                                [
                                    'user',
                                    'stage',
                                    'rating',
                                    'category',
                                    'properties',
                                    'comment_threads',
                                    'comment_threads.comments',
                                ]
    );

    # Image Not Found
    if (
        $loaded == 0
        ||
        ! defined $image
    )
    {
        $LOGGER->warn( 'Could not find image with ID >' . $image_id . '< in database.' );
        return {};
    }

    # Image Found
    my $image_hash = {};
    $image_hash->{'content'} = $image;

    my $filtered_data = {};

    # BBCode Parsing
    foreach my $key ( qw/ description / )
    {
        $filtered_data->{$key} = Side7::Utils::Text::parse_bbcode_markup( $image->$key, {} );
    }

    $filtered_data->{'filesize'} =
                Side7::Utils::File::get_formatted_filesize_from_bytes( bytes => $image->filesize );

    # Filter profanity
    if ( $filter_profanity == 1 )
    {
        foreach my $key ( qw/ title description / )
        {
            my $text = ( exists $filtered_data->{$key} ) ? $filtered_data->{$key} : $image->$key;
            $filtered_data->{$key} = Side7::Utils::Text::filter_profanity( text => $text );
        }
    }

    # Image Rating Stylizing and Qualifiers
    $filtered_data->{'rating'} = $image->rating->rating;
    if ( defined $image->rating_qualifiers && $image->rating_qualifiers ne '' )
    {
        $filtered_data->{'rating'} .= ' (' . $image->rating_qualifiers . ')';
    }

    # Fetch Image Comments
    my $image_comments =
        Side7::UserContent::CommentThread::get_all_comments_for_content(
                                                                        content_type => $image->content_type,
                                                                        content_id   => $image_id
                                                                       ) // [];
    $image_hash->{'comment_threads'} = $image_comments if defined $image_comments;

    # Filepath
    my ( $filepath, $error ) = $image->get_cached_image_path( size => $size );
    if ( defined $error && $error ne '' )
    {
        $LOGGER->warn( $error );
        $image_hash->{'filepath_error'} = $error;
    }
    else
    {
        if ( ! -f $filepath )
        {
            my ( $success, $error ) = $image->create_cached_file( size => $size, path => $filepath );

            if ( ! $success )
            {
                $LOGGER->warn( $error );
                $image_hash->{'filepath_error'} = $error;
                $image_hash->{'filepath'}       = Side7::UserContent::get_default_thumbnail_path(
                                                                                                    type => 'default_image',
                                                                                                    size => $size,
                                                                                                );
            }
            else {
                $filepath =~ s/^\/data//;
                $image_hash->{'filepath'} = $filepath;
            }
        }
        else
        {
            $filepath =~ s/^\/data//;
            $image_hash->{'filepath'} = $filepath;
        }
    }

    # Add a new view
    ### Increase Daily View counter.
    my $daily_updated = Side7::UserContent::Image::DailyView::update_daily_views( image_id => $image_id );

    if ( ! defined $daily_updated )
    {
        $LOGGER->warn( 'Could not update daily view count for Image ID: >' . $image_id . '<.' );
    }

    ### Insert new Detailed View record, including date, IP info, user agent info, and referrer info.
    my $detailed_updated = Side7::UserContent::Image::DetailedView::add_detailed_view(
                                                                                        image_id => $image_id,
                                                                                        request  => $request,
                                                                                        session  => $session,
                                                                                     );

    if ( ! defined $detailed_updated )
    {
        $LOGGER->warn( 'Could not update detailed view for Image ID: >' . $image_id . '<.' );
    }

    # Get total views
    $image_hash->{'total_views'} =
        Side7::UserContent::Image::DailyView::get_total_views_count( image_id => $image_id ) // 0;

    $image_hash->{'filtered_content'} = $filtered_data;

    return $image_hash;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
