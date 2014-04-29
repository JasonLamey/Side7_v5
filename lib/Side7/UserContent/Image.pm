package Side7::UserContent::Image;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Data::Dumper;

use Side7::Globals;
use Side7::UserContent::Image::DailyView::Manager;
use Side7::UserContent::Image::DetailedView::Manager;
use Side7::UserContent::Comment;
use Side7::Utils::File;
use Side7::Utils::Text;
use Side7::Utils::Image;

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
    ],
);

=head1 METHODS

=head2 get_image_path()

Returns the path to the image file to be used to display the image.

Parameters:

=over 4

=item size: The image size to return. Valid values are 'tiny', 'small', 'medium', 'large', 'original'. Default is 'original'.

=back

    my ( $image_path, $error ) = $image->get_image_path( size => $size );

=cut

sub get_image_path
{
    my ( $self, %args ) = @_;

    return undef if ! defined $self;

    my $size = delete $args{'size'} // 'original';

    my ( $success, $error, $image_path ) =
            Side7::Utils::File::create_user_cached_file_directory( 
                                                                    user_id      => $self->user_id, 
                                                                    content_type => 'images', 
                                                                    content_size => $size
                                                                 );

    if ( ! $success )
    {
        return ( undef, $error );
    }

    my $user_gallery_path = $self->user->get_content_directory();

    my $original_image = Image::Magick->new();

    my ( $width, $height, $filesize, $format ) = $original_image->Ping( $user_gallery_path . $self->filename );

    if ( ! defined $format )
    {
        $LOGGER->warn( 'Getting image path FAILED while getting properties of input file >' . $user_gallery_path . $self->filename . '<' );
        return( undef, 'A problem occurred while trying to get Image file.' );
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
        return( undef, 'Invalid image file type.' );
    }

    my $filename = $self->id . $extension;

    return ( $image_path . '/' . $filename, undef );
}


=head2 get_image_hash_for_template()

    my $image_hash = $image->get_image_hash_for_template();

=over 4

=item Takes Image object and converts it into an easily accessible hash to pass to the templates.  Additionally, it formats the associated dates properly for output.

=back

=cut

sub get_image_hash_for_template
{
    my $self = shift;

    return {} if ! defined $self;

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
    $image_hash->{'filesize'} = Side7::Utils::File::get_formatted_filesize_from_bytes( $self->filesize );

    # Date values
    foreach my $key ( qw( created_at updated_at ) )
    {
        my $date = $self->$key( format => '%A, %c' );
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
        $image_hash->{$key} = $date;
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

    return $image_hash;
}


=head2 create_cached_file()

Creates a copy of the original file in the appropriate cached_file directory. Returns success or error.

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
        $path = $self->get_image_path( size => $size );
    }

    my ( $success, $error ) = Side7::Utils::Image::create_cached_image( image => $self, size => $size, path => $path );
   
    if ( ! defined $success )
    {
        $LOGGER->warn( "Could not create cached image file for >$self->filename<, ID: >$self->id<: $error" );
        return ( 0, 'Could not create cached image.' );
    } 

    return ( $success, undef );
}


=head1 FUNCTIONS


=head2 show_image()

    my $image = Side7::UserContent::Image::show_image( image_id => $image_id );

=over 4

=item Returns an image hash for the requested image, for the display page.

=item Returns nothing if image_id doesn't exist.

=back

=cut

sub show_image
{
    my ( %args ) = @_;

    my $image_id = delete $args{'image_id'};
    my $request  = delete $args{'request'};
    my $session  = delete $args{'session'};
    my $size     = delete $args{'size'} // 'original';

    return if ( ! defined $image_id );

    my $image = Side7::UserContent::Image->new( id => $image_id );
    my $loaded = $image->load( 
                                speculative => 1, 
                                with => 
                                [ 
                                    'user',
                                    'rating',
                                    'category',
                                    'stage',
                                    'properties',
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
        return;
    }

    # Image Found
    my $image_hash = $image->get_image_hash_for_template() // {};

    # Fetch Image Comments
    my $image_comments = 
        Side7::UserContent::CommentThread::get_all_comments_for_content( 
                                                                        content_type => 'image', 
                                                                        content_id   => $image_id
                                                                       ) // [];
    $image_hash->{'comment_threads'} = $image_comments if defined $image_comments;

    # Filepath
    my ( $filepath, $error ) = $image->get_image_path( size => $size );
    if ( defined $error && $error ne '' )
    {
        $LOGGER->warn( $error );
        $image_hash->{'filepath_error'} = $error;
        $image_hash->{'filepath'} = '';
    }
    else
    {
        if ( ! -f $filepath )
        {
            my ( $success, $error ) = $image->create_cached_file( size => $size );

            if ( ! $success )
            {
                $image_hash->{'filepath_error'} = $error;
                $image_hash->{'filepath'}       = '';
            }
            else
            {
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

    return $image_hash;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
