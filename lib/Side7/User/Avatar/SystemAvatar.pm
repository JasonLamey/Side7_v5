package Side7::User::Avatar::SystemAvatar;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Data::Dumper;

use Side7::Globals;

use Side7::User::Avatar::SystemAvatar::Manager;
use Side7::Utils::File;
use Side7::Utils::Image;
use Side7::UserContent;

=pod


=head1 NAME

Side7::User::Avatar::SystemAvatar


=head1 DESCRIPTION

Provides access to System Avatar objects.


=head1 SCHEMA INFORMATION

    Table name: system_avatars

    | id         | bigint(20) unsigned | NO   | PRI | NULL    |       |
    | filename   | varchar(255)        | NO   |     | NULL    |       |
    | title      | varchar(255)        | YES  |     | NULL    |       |
    | created_at | datetime            | NO   |     | NULL    |       |
    | updated_at | datetime            | NO   |     | NULL    |       |


=head1 RELATIONSHIPS

=over

=item Side7::Account

One-to-one relationship, with id as the FK to Accounts

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'system_avatars',
    columns => [ 
        id         => { type => 'serial', not_null => 1 },
        filename   => { type => 'varchar', length => 255, not_null => 1 }, 
        title      => { type => 'varchar', length => 255 }, 
        created_at => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [],
    relationships =>
    [
        account =>
        {
            type       => 'one to one',
            class      => 'Side7::Account',
            column_map => { id => 'avatar_id' },
        },
    ],
);

=head1 METHODS


=head2 get_avatar_uri()

Returns a string of the URI to the avatar's image file.

Parameters:

=over 4

=item size: The size to use for the avatar's image

=item id: The ID of the avatar image.

=back

    my $avatar_uri = Side7::User::Avatar::SystemAvatar->get_avatar_uri( id => $avatar_id, size => $size );

=cut

sub get_avatar_uri
{
    my ( $self, %args ) = @_;

    my $avatar_id = delete $args{'avatar_id'} // undef;
    my $size      = delete $args{'size'}      // 'small';

    if ( ! defined $avatar_id )
    {
        $LOGGER->warn( 'Invalid or undefined avatar_id provided.' );
        return Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size );
    }

    my $avatar = Side7::User::Avatar::SystemAvatar->new( id => $avatar_id );
    my $loaded = $avatar->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not load Avatar object from the database based on avatar_id >' . $avatar_id . '<.' );
        return Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size );
    }

    my ( $uri, $error ) = $avatar->get_cached_avatar_path( size => $size );

    if ( defined $error && $error ne '' )
    {
        $LOGGER->warn( $error );
    }

    if ( ! -f $uri )
    {
        my ( $success, $error ) = Side7::Utils::Image::create_cached_avatar( 
                                                                            image          => $avatar, 
                                                                            size           => $size, 
                                                                            path           => $uri, 
                                                                            original_image => $CONFIG->{'system_avatar'}->{'original_file_path'} . $avatar->filename(),
        );
        if ( defined $error && $error ne '' )
        {
            $LOGGER->warn( $error );
            return Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size );
        }
    }

    return $uri;
}


=head2 get_cached_avatar_path()

Returns the path to the cached avatar file to be used to display the avatar image.

Parameters:

=over 4

=item size: The image size to return. Valid values are 'tiny', 'small', 'medium', 'large', 'original'. Default is 'original'.

=back

    my ( $avatar_path, $error ) = $avatar->get_cached_avatar_path( size => $size );

=cut

sub get_cached_avatar_path
{
    my ( $self, %args ) = @_; 

    return undef if ! defined $self;

    my $size = delete $args{'size'} // 'original';

    my $cached_file_path   = $CONFIG->{'system_avatar'}->{'cached_file_path'};
    my $system_avatar_path = $CONFIG->{'system_avatar'}->{'original_file_path'};

    my $original_image = Image::Magick->new();

    my ( $width, $height, $filesize, $format ) = $original_image->Ping( $system_avatar_path . $self->filename );

    if ( ! defined $format )
    {
        $LOGGER->warn( 'Getting avatar path FAILED while getting properties of input file >' . $system_avatar_path . $self->filename . '<' );
        return( 
                Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size ),
                'A problem occurred while trying to get Avatar file.'
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

    my $avatar_path = $cached_file_path . lc( $size ) . '/' . $filename;

    return ( $avatar_path, undef );
}


=head2 create_cached_file()

Creates a copy of the original file in the appropriate cached_file directory if it doesn't exist. Returns success or error.
Returns success if already existent.

Parameters:

=over 4

=item size: The image size. Valid values are 'tiny', 'small', 'medium', 'large', 'original'

=back

    my ( $success, $error ) = $avatar->create_cached_file( size => $size );

=cut

sub create_cached_file
{
    my ( $self, %args ) = @_;
    
    return ( 0, 'Invalid Avatar Object' ) if ! defined $self;

    my $size = delete $args{'size'} // undef;
    my $path = delete $args{'path'} // undef;

    if ( ! defined $size )
    {
        return ( 0, 'Invalid avatar size passed.' );
    }

    if ( ! defined $path || $path eq '' )
    {
        $path = $self->get_cached_avatar_path( size => $size );
    }

    my ( $success, $error ) = Side7::Utils::Image::create_cached_avatar( image => $self, size => $size, path => $path );

    if ( ! defined $success )
    {
        $LOGGER->warn( "Could not create cached avatar file for >$self->filename<, ID: >$self->id<: $error" );
        return ( 0, 'Could not create cached avatar image.' );
    }

    return ( $success, undef );
}


=head2 get_all_system_avatars()

Returns an arrayref of hashes with Avatar information.

Parameters:

=over 4

=item size: The image size. Valid values are 'tiny', 'small', 'medium', 'large', 'original'

=back

    my $system_avatars = Side7::User::Avatar::SystemAvatar->get_all_system_avatars( size => $size );

=cut

sub get_all_system_avatars
{
    my ( $self, %args ) = @_;

    my $size = delete $args{'size'} // 'small';

    my @avatars = ();

    foreach my $avatar ( @{ Side7::User::Avatar::SystemAvatar::Manager->get_system_avatars( sort_by => 'title asc' ) } )
    {    
        my $filepath = Side7::User::Avatar::SystemAvatar->get_avatar_uri( avatar_id => $avatar->id(), size => $size );

        if ( ! -f $filepath )
        {
            $LOGGER->warn( 'Avatar file >' . $filepath . '< does not exist when fetching all avatars.' );
            $filepath = Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size );
        }

        $filepath =~ s/^\/data//;

        push( @avatars, { 
                            avatar_id  => $avatar->id(),
                            filename   => $avatar->filename(),
                            title      => $avatar->title(),
                            created_at => $avatar->created_at(),
                            updated_at => $avatar->updated_at(),
                            uri        => $filepath,
                        }
        );
    }    

    return \@avatars;
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
