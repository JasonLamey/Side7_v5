package Side7::User;

use strict;
use warnings;

use base 'Side7::DB::Object';

use List::Util;
use Data::Dumper;
use POSIX;
use DateTime;
use Rose::DB::Object::QueryBuilder;

use Side7::Globals;
use Side7::User::Manager;
use Side7::UserContent;
use Side7::UserContent::Image;
use Side7::UserContent::Music;
use Side7::UserContent::Album;
use Side7::UserContent::Album::Manager;
use Side7::User::AOTD;
use Side7::User::Role;
use Side7::User::Permission;
use Side7::User::UserOwnedPermission;
use Side7::User::UserOwnedPermission::Manager;
use Side7::User::Perk;
use Side7::User::UserOwnedPerk;
use Side7::User::UserOwnedPerk::Manager;
use Side7::User::Preference;
use Side7::User::Avatar;
use Side7::User::Avatar::UserAvatar;
use Side7::User::Avatar::UserAvatar::Manager;
use Side7::User::Friend::Manager;
use Side7::ActivityLog::Manager;
use Side7::Utils::Crypt;
use Side7::Utils::File;
use Side7::Utils::Text;
use Side7::Utils::DateTime;
use Side7::Report;

use version; our $VERSION = qv( '0.1.39' );

=pod

=head1 NAME

Side7::User

=head1 DESCRIPTION

This class represents a user - someone who can log into the system.  For this app,
the user class is only used for login, log out, sign up, subscription and termination purposes.

=head1 SCHEMA INFORMATION

	Table name: users

	id              :integer          not null, primary key
	username        :string(45)
	email_address   :string(255)
	password        :string(45)
	referred_by     :string(45)
	created_at      :datetime         not null
	updated_at      :datetime         not null

=head1 RELATIONSHIPS

=over 4

=item Side7::Account

One-to-one relationship. FK = user_id

=item Side7::UserContent::Image

One-to-many relationship. FK = image_id

=item Side7::UserContent::Image::DetailedView

One-to-many relationship. FK = image_id

=back

=cut

__PACKAGE__->meta->setup
(
    table   => 'users',
    columns => [
        id            => { type => 'integer', not_null => 1 },
        username      => { type => 'varchar', length => 45,  not_null => 1 },
        email_address => { type => 'varchar', length => 255, not_null => 1 },
        password      => { type => 'varchar', length => 45,  not_null => 1 },
        referred_by   => { type => 'varchar', length => 45 },
        created_at    => { type => 'timestamp', not_null => 1, default => 'now()' },
        updated_at    => { type => 'timestamp', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'username' ], [ 'email_address' ], ],
    relationships =>
    [
        account =>
        {
            type       => 'one to one',
            class      => 'Side7::Account',
            column_map => { id => 'user_id' },
        },
        user_preferences =>
        {
            type       => 'one to one',
            class      => 'Side7::User::Preference',
            column_map => { id => 'user_id' },
        },
        user_owned_permissions =>
        {
            type       => 'one to many',
            class      => 'Side7::User::UserOwnedPermission',
            column_map => { id => 'user_id' },
        },
        user_owned_perks =>
        {
            type       => 'one to many',
            class      => 'Side7::User::UserOwnedPerk',
            column_map => { id => 'user_id' },
        },
        albums =>
        {
            type       => 'one to many',
            class      => 'Side7::UserContent::Album',
            column_map => { id => 'user_id' },
        },
        images =>
        {
            type       => 'one to many',
            class      => 'Side7::UserContent::Image',
            column_map => { id => 'user_id' },
        },
        image_detailed_views =>
        {
            type       => 'one to many',
            class      => 'Side7::UserContent::Image::DetailedView',
            column_map => { id => 'user_id' },
        },
        kudos_coins =>
        {
            type       => 'one to many',
            class      => 'Side7::KudosCoin',
            column_map => { id => 'user_id' },
        },
        user_avatars =>
        {
            type       => 'one to many',
            class      => 'Side7::User::Avatar::UserAvatar',
            column_map => { id => 'user_id' },
        },
        friends =>
        {
            type       => 'one to many',
            class      => 'Side7::User::Friend',
            column_map => { id => 'user_id' },
        },
        friend_ofs =>
        {
            type       => 'one to many',
            class      => 'Side7::User::Friend',
            column_map => { id => 'friend_id' },
        },
        private_messages_sent =>
        {
            type       => 'one to many',
            class      => 'Side7::PrivateMessage',
            column_map => { id => 'sender_id' },
        },
        private_messages_received =>
        {
            type       => 'one to many',
            class      => 'Side7::PrivateMessage',
            column_map => { id => 'recipient_id' },
        },
        aotds =>
        {
            type       => 'one to many',
            class      => 'Side7::User::AOTD',
            column_map => { id => 'account_id' },
        },
    ],
    foreign_keys =>
    [
        referred_by =>
        {
            class             => 'Side7::User',
            key_columns       => { referred_by => 'id' },
            relationship_type => 'many to one',
        },
    ],
);


=head1 METHODS


=head2 get_user_hash_for_template()

Takes User object and converts it and its associated Account object (if embedded) into an easily accessible hash to pass to the
templates.  Additionally, it formats the associated dates properly for output.

    my $user_hash = $user->get_user_hash_for_template();

=cut

sub get_user_hash_for_template
{
    my ( $self, %args ) = @_;

    return {} if ! defined $self;

    my $filter_profanity = delete $args{'filter_profanity'} // 1;
    my $admin_dates      = delete $args{'admin_dates'}      // undef;

    my $user_hash = {};

    # User values
    foreach my $key ( qw( id username email_address ) )
    {
        $user_hash->{$key} = $self->$key;
    }
    # Date values
    foreach my $key ( qw( created_at updated_at ) )
    {
        my $format = '%A, %c';
        if ( $key eq 'created_at' )
        {
            $format = '%a, %d %b %Y';
        }
        my $date = $self->$key( format => $format );
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
        $user_hash->{$key} = $date;
    }

    # Account values (if included)
    if ( defined $self->{'account'} )
    {
        my $account = $self->account();
        $user_hash->{'account'} = $account->get_account_hash_for_template(
                                                                            filter_profanity => $filter_profanity,
                                                                            admin_dates      => $admin_dates,
                                                                         );
    }

    # Kudos Coins (if included)
    if ( defined $self->{'kudos_coins'} )
    {
        my $kudos_ledger = $self->{'kudos_coins'};

        $user_hash->{'kudos_coins'}->{'total'} = Side7::KudosCoin->get_current_balance( user_id => $self->id() );

        # Because we're working our ledger in reverse, we're going to be working the running balance
        # in reverse, too.  We'll be subtracting from the total balance, rather than adding the starting
        # balance.

        my $running_balance = $user_hash->{'kudos_coins'}->{'total'};
        my $prev_amount = 0;

        $user_hash->{'kudos_coins'}->{'ledger'} = [];
        foreach my $record ( reverse @{ $kudos_ledger } )
        {
            my $timestamp   = $record->get_formatted_timestamp();
            $running_balance -= $prev_amount;   # Subtracting the previous amount from the current balance.
            $prev_amount = $record->{'amount'}; # Set a new previous amount.

            push ( $user_hash->{'kudos_coins'}->{'ledger'}, {
                                                                timestamp   => $record->timestamp,
                                                                amount      => $record->{'amount'},
                                                                description => $record->{'description'},
                                                                balance     => $running_balance,
                                                            }
            );
        }
    }

    # Filter Profanity
    # Currently, the User object has nothing that we care about filtering profanity on.
#    if ( $filter_profanity == 1 )
#    {
#        foreach my $key ( qw/ / )
#        {
#            $user_hash->{$key} = Side7::Utils::Text::filter_profanity( text => $user_hash->{$key} );
#        }
#    }

    return $user_hash;
}


=head2 get_image_count()

Returns the total number of images for a given user.

    my $image_count = $user->get_image_count();

=cut

sub get_image_count
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return 0;
    }

    return Side7::UserContent::Image::Manager->get_images_count(
        query => [
            user_id => [ $self->id ],
        ],
    );
}


=head2 get_music_count()

Returns the total number of music files for a given User.

Parameters:

=over 4

=item None

=back

    my $music_count = $user->get_music_count();

=cut

sub get_music_count
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return 0;
    }

    return Side7::UserContent::Music::Manager->get_music_count(
        query => [
            user_id => [ $self->id ],
        ],
    );
}


=head2 get_content_directory( $content_type )

Returns a C<string> for the User's content directory on the filesystem.

Parameters:

=over 4

=item content_type: A C<string> determining the content type to determine the content directory. Accepts 'image', 'music', 'literature', or 'video'. Mandatory.

=back

    my $user_content_directory = $user->get_content_directory( $content_type );

=cut

sub get_content_directory
{
    my ( $self, $content_type ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    if ( ! defined $content_type )
    {
        $LOGGER->warn( 'No content_type provided.' );
        return;
    }

    my $user_subdir = $self->get_user_id_path();

    if ( lc( $content_type ) eq 'image' )
    {
        if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $user_subdir )
        {
            my ( $success, $error ) = Side7::Utils::File::create_user_directory( $self->id );
            if ( defined $error )
            {
                $LOGGER->warning( $error );
            }
        }
        return $CONFIG->{'general'}->{'base_gallery_directory'} . $user_subdir;
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
        if ( ! -d $CONFIG->{'general'}->{'base_music_directory'} . $user_subdir )
        {
            my ( $success, $error ) = Side7::Utils::File::create_user_directory( $self->id );
            if ( defined $error )
            {
                $LOGGER->warning( $error );
            }
        }
        return $CONFIG->{'general'}->{'base_music_directory'} . $user_subdir;
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
    }
    elsif ( lc( $content_type ) eq 'video' )
    {
    }

    $LOGGER->warn( 'Invalid content_type provided: >' . $content_type . '<.' );
    return;
}


=head2 get_avatar_directory()

Returns a string for the User's avatar directory on the filesystem.

    my $user_avatar_directory = $user->get_avatar_directory();

=cut

sub get_avatar_directory
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    my $content_directory = $self->get_content_directory( 'image' ) . 'avatars/';

    if ( ! -d $content_directory )
    {
        my ( $success, $error ) = Side7::Utils::File::create_user_directory( $self->id );
        if ( defined $error )
        {
            $LOGGER->warning( $error );
        }
    }

    return $content_directory;
}


=head2 get_album_artwork_directory()

Returns a C<string> for the User's album artwork directory on the filesystem.

    my $user_album_artwork_directory = $user->get_album_artwork_directory();

=cut

sub get_album_artwork_directory
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    my $content_directory = $self->get_content_directory( 'image' ) . 'album_artwork/';

    if ( ! -d $content_directory )
    {
        my ( $success, $error ) = Side7::Utils::File::create_user_directory( $self->id );
        if ( defined $error )
        {
            $LOGGER->warning( $error );
        }
    }

    return $content_directory;
}


=head2 get_content_uri()

Returns a string for the User's content URI. This is different from get_content_directory as it's relative
to the domain, not to the filesystem.

    my $user_content_uri = $user->get_content_uri();

=cut

sub get_content_uri
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    my $content_uri = $CONFIG->{'general'}->{'base_gallery_uri'} . $self->get_user_id_path();

    return $content_uri;
}


=head1 get_user_id_path()

Returns a string containing the User's content directory structure built from the User's ID. This is not
a full path.

Parameters: None

    my $uid_path = $user->get_user_id_path();

=cut

sub get_user_id_path
{
    my ( $self ) = @_;

    if ( ! defined $self || ref( $self ) ne 'Side7::User' )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    return substr( $self->id, 0, 1 ) . '/' . substr( $self->id, 0, 3 ) . '/' . $self->id . '/';
}


=head2 get_gallery()

Returns an arrayref of User Content belonging to the specified User.

Parameters:

=over 4

=item session: The visitor's session hash from the request.

=item sort_by: The field to sort by. Defaults to 'created_at'. Accepts 'created_at', 'title', 'content_type'.

=item sort_order: The direction to sort in. Defaults to 'desc'. Accepts 'desc', 'asc'.

=back

    my $gallery = $user->get_gallery( session => $session );

=cut

sub get_gallery
{
    my ( $self, %args ) = @_;

    my $sort_by    = $args{'sort_by'}    // 'created_at';
    my $sort_order = $args{'sort_order'} // 'desc';

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    my $session = delete $args{'session'} // undef;

    # TODO: BUILD OUT ADDITIONAL, OPTIONAL ARGUMENTS TO CONTROL CONTENT.
    my $gallery = Side7::UserContent::get_gallery( $self->id , session => $session, sort_by => $sort_by, sort_order => $sort_order );

    return $gallery;
}


=head2 get_albums()

Returns an arrayref of Album objects that belong to the User.

Parameters: None.

    my $albums = $user->get_albums();

=cut

sub get_albums
{
    my ( $self ) = @_;

    my $albums = Side7::UserContent::Album::Manager->get_albums(
                                                                query => [
                                                                            user_id => $self->id,
                                                                         ],
                                                                sort_by => 'system DESC,name ASC',
                                                               ) // [];

    foreach my $album ( @$albums )
    {
        $album->{'content_count'} = $album->get_content_count();
    }

    return $albums;
}


=head2 get_all_content()

Returns an arrayref of UserContent objects associated with the User.

Parameters: None.

    my $content = $user->get_all_content();

=cut

sub get_all_content
{
    my ( $self, %args ) = @_;

    my $sort_by = $args{'sort_by'} // 'created_by desc';

    my @results;

    # Images
    my $images = Side7::UserContent::Image::Manager->get_images
    (
        query =>
        [
            user_id => [ $self->id() ],
        ],
        with_objects => [ 'rating', 'category', 'stage' ],
        sort_by => $sort_by,
    );

    push( @results, @$images );

    # TODO: Literature

    # Music
    my $music = Side7::UserContent::Music::Manager->get_music
    (
        query =>
        [
            user_id => [ $self->id() ],
        ],
        with_objects => [ 'rating', 'category', 'stage' ],
        sort_by => $sort_by,
    );

    push( @results, @$music );


    return \@results;
}


=head2 get_formatted_created_at()

Returns a string containing the C<created_at> field formatted appropriately for display.

Parameters:

=over

=item date_format: A DateTime compatible format for how the date should be displayed. Defaults to '%A, %d %B, %Y'

=back

    my $created_at = $user->get_formatted_created_at( date_format => $date_format );

=cut

sub get_formatted_created_at
{
    my ( $self, %args ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    my $date_format = delete $args{'date_format'} // '%A, %d %B, %Y';

    my $date = $self->created_at( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_formatted_updated_at()

Returns a string containing the C<updated_at> field formatted appropriately for display.

Parameters:

=over

=item date_format: A DateTime compatible format for how the date should be displayed. Defaults to '%A, %d %B, %Y'

=back

    my $updated_at = $user->get_formatted_updated_at( date_format => $date_format );

=cut

sub get_formatted_updated_at
{
    my ( $self, %args ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    my $date_format = delete $args{'date_format'} // '%A, %d %B, %Y';

    my $date = $self->updated_at( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_avatar()

Returns the URI of the Avatar to be displayed for the User. Because get_avatar can and is called
from templates, nnd Template::Toolkit passes in named arguments as a hashref, arguments to get_avatar
must be in a hashref.

Parameters:

=over 4

=item size: The image size of the Avatar. Accepts 'tiny', 'small', 'medium', 'large', 'original'.  Default: 'small'

=back

    my $avatar = $user->get_avatar( { size => 'large' } );

=cut

sub get_avatar
{
    my ( $self, $args ) = @_;

    my $size = delete $args->{'size'} // 'small';

    return Side7::User::Avatar->get_avatar( user => $self, size => lc( $size ) );
}


=head2 get_all_avatars()

Returns an arrayref of hashes of all Avatars belonging to the User.

Parameters:

=over 4

=item size: The image size of the Avatar. Accepts 'tiny', 'small', 'medium', 'large', 'original'.  Default: 'small'

=back

    my $user_avatars = $user->get_all_avatars( size => 'large' );

=cut

sub get_all_avatars
{
    my ( $self, %args ) = @_;

    my $size = delete $args{'size'} // 'small';

    my @avatars = ();

    foreach my $avatar ( $self->user_avatars() )
    {
        my $filepath = Side7::User::Avatar::UserAvatar->get_avatar_uri( avatar_id => $avatar->id(), size => $size );

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


=head2 has_permission()

Checks against Side7::User::Role and Side7::User::UserOwnedPermission to see if the account has
the requested permission.

Parameters:

=over 4

=item permission: The permission being checked against.

=back

    my $has_permission = $user->has_permission( 'permission_name' );

=cut

sub has_permission
{
    my ( $self, $permission_name ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    return 0 if ! defined $permission_name;

    # Does the permission that is being requested exist?
    my $permission = Side7::User::Permission->new( name => $permission_name );
    my $loaded = $permission->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->error(
                        'Could not load Permission >' . $permission_name .
                        '< for User >' . $self->username . '<, ID >' . $self->id . '<.'
        );
        return 0;
    }

    # Get the User's Role.
    my $role = Side7::User::Role->new( id => $self->account->user_role_id );
    $loaded = $role->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->error(
                        'Could not load User Role >' . $self->account->user_role_id .
                        '< for User >' . $self->username . '<, ID >' . $self->id . '<.'
        );
        return 0;
    }

    # Check to see if the Role has the permission.
    my $role_has_permission = $role->has_permission( $permission_name );

    # See if the User has the permission owned, and also ensure it's not revoked or suspended.
    my $user_owned_permission = Side7::User::UserOwnedPermission->new(
                                                                        user_id       => $self->id,
                                                                        permission_id => $permission->id
                                                                     );
    my $uop_loaded = $user_owned_permission->load( speculative => 1 );

    if ( $uop_loaded != 0 )
    {
        if (
            $user_owned_permission->suspended == 1
            ||
            $user_owned_permission->revoked == 1
        )
        {
            $LOGGER->info(
                            'User Permission suspended or revoked for Permission >' . $permission_name .
                            '< for User >' . $self->username . '<, ID >' . $self->id . '<.'
            );
            return 0;
        }
    }

    # If the role has the permission, or the User has purchased the permission, return true.
    if (
        $role_has_permission == 1
        ||
        $uop_loaded != 0
    )
    {
        return 1;
    }

    # No permission.
    return 0;
}


=head2 get_all_permissions()

Fetches all permissions a User has, based on their User Role and purchased Permissions.

    my @permissions = $user->get_all_permissions();

=cut

sub get_all_permissions
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    # Get the User's Role.
    my $role = Side7::User::Role->new( id => $self->account->user_role_id );
    my $loaded = $role->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->error(
                        'Could not load User Role >' . $self->account->user_role_id .
                        '< for User >' . $self->username . '<, ID >' . $self->id . '<.'
        );
        return [];
    }

    my $role_based_permissions = $role->permissions();

    my @permissions = ();
    foreach my $permission ( @{ $role_based_permissions } )
    {
        push (
                @permissions, {
                                id           => $permission->id,
                                name         => $permission->name,
                                description  => $permission->description,
                                purchaseable => $permission->purchaseable,
                            }
        );
    }


    my $user_owned_permissions
            = Side7::User::UserOwnedPermission::Manager->get_user_owned_permissions(
                query =>
                [
                    user_id => [ $self->id ],
                ],
                with_objects => [ 'permission' ],
            );

    foreach my $permission ( @{ $user_owned_permissions } )
    {
        push (
                @permissions, {
                                id           => $permission->permission->id,
                                name         => $permission->permission->name,
                                description  => $permission->permission->description,
                                purchaseable => $permission->permission->purchaseable,
                                suspended    => $permission->suspended,
                                reinstate_on => $permission->reinstate_on,
                                revoked      => $permission->revoked,
                            }
        );
    }

    return \@permissions;
}

=head2 get_all_perks()

Fetches all perks a User has, based on their User Role and purchased Perks.

    my @perks = $user->get_all_perks();

=cut

sub get_all_perks
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return;
    }

    # Get the User's Role.
    my $role = Side7::User::Role->new( id => $self->account->user_role_id );
    my $loaded = $role->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->error(
                        'Could not load User Role >' . $self->account->user_role_id .
                        '< for User >' . $self->username . '<, ID >' . $self->id . '<.'
        );
        return [];
    }

    my $role_based_perks = $role->perks();

    my @perks = ();
    foreach my $perk ( @{ $role_based_perks } )
    {
        push (
                @perks, {
                            id           => $perk->id,
                            name         => $perk->name,
                            description  => $perk->description,
                            purchaseable => $perk->purchaseable,
                        }
        );
    }


    my $user_owned_perks
            = Side7::User::UserOwnedPerk::Manager->get_user_owned_perks(
                query =>
                [
                    user_id => [ $self->id ],
                ],
                with_objects => [ 'perk' ],
            );

    foreach my $perk ( @{ $user_owned_perks } )
    {
        push (
                @perks, {
                          id           => $perk->perk->id,
                          name         => $perk->perk->name,
                          description  => $perk->perk->description,
                          purchaseable => $perk->perk->purchaseable,
                          suspended    => $perk->suspended,
                          reinstate_on => $perk->reinstate_on,
                          revoked      => $perk->revoked,
                        }
        );
    }

    return \@perks;
}


=head2 is_valid_password()

Tests to see if a provided password is valid, and if the password is in a non-SHA1 format, it converts it to one.
Returns an arrayref of success code, and error.

Parameters:

=over4

=item password: The plain-text password the User supplied.

=back

    my ( $success, $error ) = $user->is_valid_password( $password );

=cut

sub is_valid_password
{
    my ( $self, $password ) = @_;

    return ( 0, 'Invalid password provided: blank password' ) if ! defined $password;

    my $digest = Side7::Utils::Crypt::sha1_hex_encode( $password );

    if ( $digest eq $self->{'password'} )
    {
        return ( 1, undef );
    }

    my $md5_hex = Side7::Utils::Crypt::md5_hex_encode( $password );

    if ( $md5_hex eq $self->{'password'} )
    {
        # If the password is MD5_hex, let's convert it to SHA1.
        $self->{'password'} = $digest;
        $self->save;

        return ( 1, undef );
    }

    my $crypt = Side7::Utils::Crypt::old_side7_crypt( $password );

    if ( $crypt eq $self->{'password'} )
    {
        # If the password is crypted, let's convert it to SHA1.
        $self->{'password'} = $digest;
        $self->save;

        return ( 1, undef );
    }

    my $db_pass = Side7::Utils::Crypt::old_mysql_password( $password );

    if ( $db_pass eq $self->{'password'} )
    {
        # If the password is db password, let's convert it to SHA1.
        $self->{'password'} = $digest;
        $self->save;

        return ( 1, undef );
    }

    #$LOGGER->debug( "Password compare: db - >$user->{'password'}<; di - >$digest<; md - >$md5_hex<; cr - >$crypt<; db - >$db_pass<" );

    return ( 0, 'Invalid credentials provided. Check that you have typed your username and/or password correctly.' );
}


=head2 get_activity_logs()

Fetches an arrayref of C<ActivityLog> objects, and returns an arrayref of hashes containing the pertinent C<ActivityLog> data to feed
to the templates.

Parameters:

=over 4

=item limit: Number of logs to return; defaults to 20;

=back

    my $activity_logs = $user->get_activity_logs();

=cut

sub get_activity_logs
{
    my ( $self, %args ) = @_;

    my $limit = delete $args{'limit'} // 20;

    my @approved_friends = ();
    foreach my $raw_friend ( @{ $self->friends() } )
    {
        if ( $raw_friend->status() eq 'Approved' )
        {
            push( @approved_friends, $raw_friend->friend_id() );
        }
    }

    if ( scalar( @approved_friends ) == 0 )
    {
        return [];
    }

    my $logs = Side7::ActivityLog::Manager->get_activity_logs(
                                                               query => [
                                                                            user_id => \@approved_friends,
                                                                        ],
                                                               limit   => $limit,
                                                               sort_by => 'created_at desc'
                                                             );

    my $activity_logs = [];
    foreach my $log ( @$logs )
    {
        push( @$activity_logs, {
                                    id           => $log->id(),
                                    user_id      => $log->user_id(),
                                    activity     => $log->activity(),
                                    created_at   => $log->created_at(),
                                    elapsed_time => Side7::Utils::DateTime->get_english_elapsed_time( seconds => $log->created_at()->epoch() ),
                               }
        );
    }

    return $activity_logs;
}


=head2 get_friends_by_status()

Returns an arrayref of Friend objects based on the passed in Friend Request status.

Parameters:

=over 4

=item status: Accepts 'Pending', 'Accepted', 'Ignored', 'Denied'.  Default: 'Accepted'

=back

    my $friends = $user->get_friends_by_status( status => $status );

=cut

sub get_friends_by_status
{
    my ( $self, %args ) = @_;

    my $status = delete $args{'status'} // 'Accepted';

    my $friends = [];

    $friends = Side7::User::Friend::Manager->get_friends(
                                                            query => [
                                                                        user_id => $self->id(),
                                                                        status  => $status,
                                                                     ],
                                                            sort_by      => 'account.last_name ASC, account.first_name ASC',
                                                            with_objects => [ 'friend', 'friend.account' ],
                                                        );

    return $friends;
}


=head2 get_friends_by_id()

Returns an arrayref of Friend objects based on the passed in Friend Request status.

Parameters:

=over 4

=item ids: arrayref of user_ids for which to search.

=back

    my $user_ids = [ 1, 4, 6, 8 ];
    my $friends = $user->get_friends_by_id( user_ids => $user_ids );

=cut

sub get_friends_by_id
{
    my ( $self, %args ) = @_;

    my $user_ids = delete $args{'user_ids'} // [];

    $LOGGER->warn( 'USER_IDS RECEIVED: ' . Dumper( $user_ids ) );

    return [] if ! defined $user_ids || scalar( @{ $user_ids } ) == 0;

    my $friends = [];

    $friends = Side7::User::Friend::Manager->get_friends(
                                                            query => [
                                                                        user_id   => $self->id(),
                                                                        status    => 'Approved',
                                                                        friend_id => $user_ids,
                                                                     ],
                                                            with_objects => [ 'friend', 'friend.account' ],
                                                        );

    return $friends;
}


=head2 get_pending_friend_requests()

Returns and arrayref of Friend Request objects for the User.

Parameters: none

    my $friend_requests = $user->get_pending_friend_requests();

=cut

sub get_pending_friend_requests
{
    my ( $self, %args ) = @_;

    my $user_id = delete $args{'user_id'} // undef;

    my $friend_requests = [];
    my %query           = ();
    $query{friend_id} = $self->id;
    $query{status}    = 'Pending';
    $query{user_id}   = $user_id if defined $user_id && $user_id =~ m/^\d+$/;

    $friend_requests = Side7::User::Friend::Manager->get_friends(
                                                                    query        => [ %query ],
                                                                    with_objects => [ 'user', 'user.account' ],
                                                                );
    return $friend_requests;
}


=head2 can_send_friend_request_to_user()

This method checks the system to ensure the conditions are right for allowing a User to
send a friend link request to another User. The conditions include:
* Does the recipient allow friending?
* Is the User already linked with the recipient?
* Does this User already have a pending friend link request?
* Has the recipient previously denied a previous friend link request from this User?
Returns a hashref containing a boolean to indicate send permission, and an error message value.  The error
value will be undef if there is no error.

Parameters:

=over 4

=item user_id: The User ID to check against.

=back

    my $can_send = $user->can_send_friend_request_to_user( user_id => $user_id );

=cut

sub can_send_friend_request_to_user
{
    my ( $self, %args ) = @_;

    my $user_id = delete $args{'user_id'} // undef;

    if ( ! defined $user_id || $user_id =~ m/\D+/ )
    {
        $LOGGER->warn( 'Invalid recipient User ID ( >' . $user_id . '< ) provided.' );
        return { can_send => 0, error => 'Can not send a Friend Link request if you do not indicate to whom to send it.' };
    }

    my $recipient = Side7::User::get_user_by_id( $user_id );

    if ( ! defined $recipient || ref( $recipient ) ne 'Side7::User' )
    {
        $LOGGER->warn( 'Invalid recipient User ID ( >' . $user_id . '< ) provided.' );
        return { can_send => 0, error => 'Not sure to whom you are trying to send a Friend Link request.' };
    }

    # Does recipient allow friending? TODO

    # Are the recipient and User already linked?
    my $existing_friends = $self->get_friends_by_id( user_ids => [ $user_id ] );
    if (
        defined $existing_friends->[0]
        &&
        $existing_friends->[0]->friend_id == $user_id
    )
    {
        return { can_send => 0, error => 'You are already Friend Linked with <b>' . $recipient->username . '</b>!' };
    }

    # Does the User already have a pending request with this recipient?
    my $pending_requests = $recipient->get_pending_friend_requests( user_id => $self->id );
    if (
        defined $pending_requests->[0]
        &&
        $pending_requests->[0]->user_id == $self->id
    )
    {
        return { can_send => 0, error => 'You already have a pending Friend Link request with <b>' . $recipient->username . '</b>!' };
    }

    # Has the recipient denied a previous friend link request from this User?
    my $denied_requests = $recipient->get_friends_by_status( status => 'Denied' );
    foreach my $request ( @{ $denied_requests } )
    {
        if ( $request->user_id == $self->id )
        {
            return { can_send => 0, error => 'Unfortunately, <b>' . $recipient->username . '</b> has already denied a Friend Link request from you. You cannot re-send a request to this User.' };
        }
    }

    return { can_send => 1, error => undef };
}


=head2 is_friend_linked

Returns a boolean value indicating if the User is currently friend-linked to the User indicated.

Parameters:

=over 4

=item user_id: The ID of the User to check against.

=back

    my $is_friend_linked = $user->is_friend_linked( user_id => $user_id );

=cut

sub is_friend_linked
{
    my ( $self, %args ) = @_;

    my $user_id = delete $args{'user_id'} // undef;

    if ( ! defined $user_id )
    {
        return 0;
    }

    # Did the User send us a Pending Friend Link Request?
    my $pending = Side7::User::Friend->new(
                                            user_id   => $user_id,
                                            friend_id => $self->id,
                                            status    => 'Pending',
                                          );

    my $ploaded = $pending->load( speculative => 1 );

    if (
        defined $pending
        &&
        ref( $pending ) eq 'Side7::User::Friend'
        &&
        $ploaded != 0
    )
    {
        # Received Pending Request exists
        return 3;
    }


    # Does an Existing Pending Friend Link Request exist
    my $friend = Side7::User::Friend->new(
                                            user_id   => $self->id,
                                            friend_id => $user_id,
                                            status    => 'Pending',
                                         );

    my $floaded = $friend->load( speculative => 1 );

    if (
        defined $friend
        &&
        ref( $friend ) eq 'Side7::User::Friend'
        &&
        $floaded != 0
    )
    {
        # Pending Request exists
        return 2;
    }

    # Does an Approved Friend Link exist
    my $is_friend = Side7::User::Friend->new(
                                                user_id   => $self->id,
                                                friend_id => $user_id,
                                                status    => 'Approved',
                                            );

    my $iloaded = $is_friend->load( speculative => 1 );

    if ( $iloaded == 0 )
    {
        # No link exists, return 0.
        return 0;
    }

    return 1;
}


=head2 get_private_messages( $msg_type )

Returns an C<arrayref> of private message objects, based on the message type indicated.

Parameters:

=over 4

=item msg_type: 'sent' or 'received'.  Defaults to 'sent'

=back

    my $pms = $user->get_private_messages( 'sent' );

=cut

sub get_private_messages
{
    my ( $self, $msg_type ) = @_;

    $msg_type //= 'sent';

    return [] if ! defined $self || ref( $self ) ne 'Side7::User';

    my $pms = [];
    if ( lc( $msg_type ) eq 'received' )
    {
        $pms = $self->private_messages_received();
    }
    else
    {
        $pms = $self->private_messages_sent();
    }

    return $pms;
}


=head2 is_role( $role )

Returns a C<boolean> as to whether the User in question is the role indicated.

Parameters:

=over 4

=item role: The role being checked against. Can be either a C<string> or an C<arrayref>. Required.

=back

    my $is_role = $user->is_role( $role );

=cut

sub is_role
{
    my ( $self, $role ) = @_;

    return 0 if ! defined $role;

    if ( ref( $role ) eq 'ARRAY' )
    {
        foreach my $check ( @{ $role } )
        {
            return 1 if $self->account->user_role->name eq $check;
        }
        return 0;
    }
    elsif ( ref( $role ) eq 'SCALAR' )
    {
        return 1 if $self->account->user_role->name eq $role;
    }
    else
    {
        $LOGGER->warn( 'Invalid ref for $role: >' . ref( $role ) . '<' );
    }

    return 0;
}


=head1 FUNCTIONS


=head2 process_signup()

Takes user sign-up information and performs some safety checks with it.  Then it creates a User object, and saves it to the database.

Parameters:

=over 4

=item username: The username field from the form.

=item password: The password field from the form.

=item email_address: The email_address field from the form.

=item birthday: The birthday field from the form.

=item confirmation_code: The confirmation_code field from the form.

=item referred_by: The User who referred the signing up User.

=back

    my $user_hash = Side7::User::process_signup(
                                                username          => $username,
                                                password          => $password,
                                                email_address     => $email_address,
                                                birthday          => $birthday,
                                                confirmation_code => $confirmation_code,
                                                referred_by       => $referred_by,
                                            );

=cut

sub process_signup
{
    my ( $args ) = @_;

    my $username          = delete $args->{'username'}          // undef;
    my $password          = delete $args->{'password'}          // undef;
    my $email_address     = delete $args->{'email_address'}     // undef;
    my $birthday          = delete $args->{'birthday'}          // undef;
    my $confirmation_code = delete $args->{'confirmation_code'} // undef;
    my $referred_by       = delete $args->{'referred_by'}       // undef;

    my $saved = 0;
    my @form_errors = ();

    # Error out if username or e-mail address already exists.
    if ( defined $username && $username ne '' )
	{
        my $user_check = Side7::User->new( username => $username );
        my $loaded = $user_check->load( speculative => 1 );
        if ( $loaded != 0 )
        {
            push @form_errors, 'A user with the Username >' . $username . '< already exists.';
        }
    }
    else
    {
        push @form_errors, 'A Username is required to create an account.';
    }

    if ( defined $email_address && $email_address ne '' )
	{
        my $email_check = Side7::User->new( email_address => $email_address );
        my $loaded = $email_check->load( speculative => 1 );
        if ( $loaded != 0 )
        {
            push @form_errors, 'A user with the E-mail Address >' . $email_address . '< already exists.';
        }
    }
    else
    {
        push @form_errors, 'An E-mail Address is required to create an account.';
    }

    if ( scalar( @form_errors ) > 0 )
    {
        return ( $saved, \@form_errors, undef );
    }

    # Save new account to database.

    my $user = Side7::User->new(
        username      => $username,
        password      => Side7::Utils::Crypt::sha1_hex_encode( $password ),
        email_address => $email_address,
        referred_by   => $referred_by,
        created_at    => 'now',
        updated_at    => 'now',
    );
    $user->save;

    my $account = Side7::Account->new(
        user_id             => $user->id,
        user_type_id        => 1, # Basic
        user_status_id      => 1, # Pending
        user_role_id        => 1, # Guest
        birthday            => $birthday,
        birthday_visibility => 1,   # Visible
        country_id          => 228, # USA
        is_public           => 0,   # Nothing is public by default
        confirmation_code   => $confirmation_code, # Used for e-mail confirmation.
        created_at          => 'now',
        updated_at          => 'now',
    );

    my $user_preferences = Side7::User::Preference->new();

    $user->account( $account );
    $user->user_preferences( $user_preferences );

    $user->save;

    $saved = 1;

    return ( $saved, \@form_errors, $user );
}


=head2 confirm_new_user()

Checks for a User account that has the confirmation_code that is passed in. If so, updates the User's status from 'Pending' to 'Active'. Creates the User's directory structure.

Parameters:

=over 4

=item confirmation_code: Just the value of the confirmation code. No default.

=back

    my ( $confirmed, $error ) = Side7::User::confirm_new_user( $confirmation_code );

=cut

sub confirm_new_user
{
    my ( $confirmation_code ) = @_;

    if ( ! defined $confirmation_code || length( $confirmation_code ) < 40 )
    {
        $LOGGER->error( 'Invalid confirmation code >' . $confirmation_code . '< passed in.' );
        return ( 0, 'The confirmation code >' . $confirmation_code . '< is invalid. Please check your code and try again.' );
    }

    my $account = Side7::Account->new( confirmation_code => $confirmation_code );
    my $loaded = $account->load( speculative => 1, with => [ 'user' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->error( 'No matching User account for confirmation code >' . $confirmation_code . '< was found.' );
        return ( 0, 'The confirmation code >' . $confirmation_code . '< is invalid. Please check your code and try again.' );
    }

    $account->user_status_id( 2 ); # Active
    $account->user_role_id( 2 );   # User
    $account->confirmation_code( undef );
    $account->updated_at( 'now' );
    $account->save;

    my ( $success, $error ) = Side7::Utils::File::create_user_directory( $account->user_id );

    # If a referrer was given, let's award that User.
    if ( defined $account->user->referred_by() )
    {
        my $referrer = Side7::User::get_user_by_username( $account->user->referred_by() );
        if ( defined $referrer && ref( $referrer ) eq 'Side7::User' )
        {
            my ( $success, $error ) = Side7::KudosCoin->give_kudos_coins(
                user_id     => $referrer->id(),
                amount      => $CONFIG->{'kudos_coins'}->{'award'}->{'referral'},
                description => 'Referral Award for referring <strong>' . $account->user->username() . '</strong>',
                purchased   => 0,
            );
            if ( ! $success )
            {
                $LOGGER->error( 'Could not award >' . $referrer->username() . '< Kudos Coins for referring >' .
                                $account->user->username() . '<' );
            }
        }
    }

    if ( ! $success )
    {
        $LOGGER->error( "Could not create User directory for ID >$account->user_id<: $error" );
    }

    return ( 1, undef );
}


=head2 confirm_password_change()

Checks for a User account that has the confirmation_code that is passed in. If so, updates the User's password to the new value.

Parameters:

=over 4

=item confirmation_code: Just the value of the confirmation code. No default.

=back

    my ( $confirmed, $error ) = Side7::User::confirm_password_change( $confirmation_code );

=cut

sub confirm_password_change
{
    my ( $confirmation_code ) = @_;

    my %change_results = ();

    if ( ! defined $confirmation_code || length( $confirmation_code ) < 40 )
    {
        $LOGGER->error( 'Invalid confirmation code >' . $confirmation_code . '< passed in.' );
        $change_results{'confirmed'} = 0;
        $change_results{'error'}     = 'The confirmation code >' . $confirmation_code .
                                        '< is invalid. Please check your code and try again.';
        return \%change_results;
    }

    my $change = Side7::User::ChangePassword->new( confirmation_code => $confirmation_code );
    my $loaded = $change->load( speculative => 1, with => [ 'user' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->error( 'No matching User account for confirmation code >' . $confirmation_code . '< was found.' );
        $change_results{'confirmed'} = 0;
        $change_results{'error'}     = 'The confirmation code >' . $confirmation_code .
                                        '< is invalid. Please check your code and try again.';
        return \%change_results;
    }

    my $new_encoded_password = Side7::Utils::Crypt::sha1_hex_encode( $change->new_password() );
    my $original_password    = $change->user->password();

    $change->user->password( $new_encoded_password );
    $change->user->updated_at( 'now' );
    $change->user->save;

    $change->delete;

    $change_results{'confirmed'}         = 1;
    $change_results{'original_password'} = $original_password;
    $change_results{'new_password'}      = $new_encoded_password;

    return \%change_results;
}


=head2 confirm_set_delete_flag()

Checks for a User account that has the confirmation_code that is passed in. If so, updates the User's delete_on to 30 days from now.

Parameters:

=over 4

=item confirmation_code: Just the value of the confirmation code. No default.

=back

    my ( $confirmed, $error ) = Side7::User::confirm_set_delete_flag( $confirmation_code );

=cut

sub confirm_set_delete_flag
{
    my ( $confirmation_code ) = @_;

    my %change_results = ();

    if ( ! defined $confirmation_code || length( $confirmation_code ) < 40 )
    {
        $LOGGER->error( 'Invalid confirmation code >' . $confirmation_code . '< passed in.' );
        $change_results{'confirmed'} = 0;
        $change_results{'error'}     = 'The confirmation code >' . $confirmation_code .
                                        '< is invalid. Please check your code and try again.';
        return \%change_results;
    }

    my $change = Side7::User::AccountDelete->new( confirmation_code => $confirmation_code );
    my $loaded = $change->load( speculative => 1, with => [ 'user', 'user.account' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->error( 'No matching User account for confirmation code >' . $confirmation_code . '< was found.' );
        $change_results{'confirmed'} = 0;
        $change_results{'error'}     = 'The confirmation code >' . $confirmation_code .
                                        '< is invalid. Please check your code and try again.';
        return \%change_results;
    }

    my $today_plus_thirty = DateTime->today()->add( days => 30 );

    $change->user->account->delete_on( $today_plus_thirty->ymd() );
    $change->user->account->updated_at( 'now' );
    $change->user->account->save;
    $change->user->updated_at( 'now' );
    $change->user->save;

    $change->delete;

    $change_results{'confirmed'} = 1;
    $change_results{'delete_on'} = $today_plus_thirty->strftime( '%A, %b %d, %Y' );

    return \%change_results;
}


=head2 clear_delete_flag()

Removes the delete_on flag from the User's account.

Parameters:

=over 4

=item username: The username for the account to clear the flag from.

    my $change_results = Side7::User::clear_delete_flag( $username );

=cut

sub clear_delete_flag
{
    my ( $username ) = @_;

    return { cleared => 0, error => 'Invalid or missing Username' } if ! defined $username;

    my $user = Side7::User::get_user_by_username( $username );

    if ( ref( $user ) ne 'Side7::User' )
    {
        return { cleared => 0, error => 'Invalid Username' };
    }

    $user->account->delete_on( undef );
    $user->account->updated_at( 'now' );
    $user->account->save();
    $user->updated_at( 'now' );
    $user->save();

    return { cleared => 1, error => undef };
}


=head2 show_profile()

Returns the User object, and any filtered data for use in the template, so that the
User's profile can be displayed properly.

Parameters:

=over 4

=item username: The username for lookup for getting the user_hash for template use.

=item filter_profanity: Boolean value deterimining if profanity should be filtered out of user content.

=back

    my ( $user, $filtered_data ) = Side7::User::show_profile( username => $username )

=cut

sub show_profile
{
    my ( %args ) = @_;

    my $username         = delete $args{'username'};
    my $filter_profanity = delete $args{'filter_profanity'} // 1;

    return if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return ();
    }

    # User Found
    my $filtered_data = {};

    $filtered_data->{'biography'} = Side7::Utils::Text::parse_bbcode_markup( $user->account->biography, {} );

    if ( $filter_profanity == 1 )
    {
        $filtered_data->{'biography_no_profanity'} = Side7::Utils::Text::filter_profanity( text => $filtered_data->{'biography'} );
    }

    return ( $user, $filtered_data );
}


=head2 show_home

Displays the User's home page.

Parameters:

=over 4

=item username: The username to use for looking up the User object to get the appropriate hash for use with the template.

=back

    my $user_hash = Side7::User::show_home( username => $username )

=cut

sub show_home
{
    my ( %args ) = @_;

    my $username = delete $args{'username'};

    return if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [
                                                            'kudos_coins?',
                                                            'user_owned_perks?',
                                                            'user_owned_permissions?',
                                                            'account'
                                                        ],
    );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return;
    }

    my $user_hash = {};
    $user_hash->{'user'} = $user;

    # Content Counts By Category
    $user_hash->{'content_data'} = Side7::Report->get_user_content_breakdown_by_category( $user->id() );

    my $disk_stats = Side7::Report->get_user_disk_usage_stats( $user );

    ( $user_hash->{'disk_quota'}, $user_hash->{'disk_quota_units'} )
                            = Side7::Utils::File::get_formatted_filesize_from_bytes(
                                                            bytes       => $disk_stats->{'disk_quota'},
                                                            force_units => 'MB',
                            );

    ( $user_hash->{'disk_used'}, undef )
            = Side7::Utils::File::get_formatted_filesize_from_bytes(
                                                            bytes       => $disk_stats->{'disk_usage'},
                                                            force_units => 'MB',
            );

    $user_hash->{'disk_used'} = POSIX::ceil( $user_hash->{'disk_used'} );

    $user_hash->{'disk_band1_start'} = 0;
    $user_hash->{'disk_band1_end'}   = int( $user_hash->{'disk_quota'} * .60 );
    $user_hash->{'disk_band2_start'} = $user_hash->{'disk_band1_end'};
    $user_hash->{'disk_band2_end'}   = int( $user_hash->{'disk_quota'} * .80 );
    $user_hash->{'disk_band3_start'} = $user_hash->{'disk_band2_end'};
    $user_hash->{'disk_band3_end'}   = $user_hash->{'disk_quota'};

    return $user_hash;
}


=head2 show_account

Displays the User's Account Management page.

Parameters:

=over 4

=item username: The username to use for looking up the User object to get the appropriate hash for use with the template.

=back

    my $user_hash = Side7::User::show_account( username => $username )

=cut

sub show_account
{
    my ( %args ) = @_;

    my $username = delete $args{'username'};

    return if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return;
    }

    return $user;
}


=head2 show_kudos

Displays the User's Kudos Coins page.

Parameters:

=over 4

=item username: The username to use for looking up the User object to get the appropriate hash for use with the template.

=back

    my $user_hash = Side7::User::show_kudos( username => $username )

=cut

sub show_kudos
{
    my ( %args ) = @_;

    my $username = delete $args{'username'};

    return if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'kudos_coins' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return;
    }

    my $user_hash = {};
    $user_hash->{'user'} = $user;

    if ( defined $user->{'kudos_coins'} )
    {
        my $kudos_ledger = $user->{'kudos_coins'};

        $user_hash->{'kudos_coins'}->{'total'} = Side7::KudosCoin->get_current_balance( user_id => $user->id() );

        # Because we're working our ledger in reverse, we're going to be working the running balance
        # in reverse, too.  We'll be subtracting from the total balance, rather than adding the starting
        # balance.

        my $running_balance = $user_hash->{'kudos_coins'}->{'total'};
        my $prev_amount = 0;

        $user_hash->{'kudos_coins'}->{'ledger'} = [];
        foreach my $record ( reverse @{ $kudos_ledger } )
        {
            my $timestamp   = $record->get_formatted_timestamp();
            $running_balance -= $prev_amount;   # Subtracting the previous amount from the current balance.
            $prev_amount = $record->{'amount'}; # Set a new previous amount.

            push ( $user_hash->{'kudos_coins'}->{'ledger'}, {
                                                                timestamp   => $record->timestamp,
                                                                amount      => $record->{'amount'},
                                                                description => $record->{'description'},
                                                                balance     => $running_balance,
                                                            }
            );
        }
    }

    return $user_hash;
}


=head2 show_gallery

Displays the User's Gallery Management page.

Parameters:

=over 4

=item username: The username to use for looking up the User object to get the appropriate hash for use with the template.

=back

    my $user_hash = Side7::User::show_gallery( username => $username )

=cut

sub show_gallery
{
    my ( %args ) = @_;

    my $username = delete $args{'username'};

    return if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [
                                                            'account'
                                                        ],
    );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return;
    }

    my $user_hash = {};
    $user_hash->{'user'} = $user;

    # Content Counts By Category
    $user_hash->{'content_data'} = Side7::Report->get_user_content_breakdown_by_category( $user->id() );

    my $disk_stats = Side7::Report->get_user_disk_usage_stats( $user );

    ( $user_hash->{'disk_quota'}, $user_hash->{'disk_quota_units'} )
                            = Side7::Utils::File::get_formatted_filesize_from_bytes(
                                                            bytes       => $disk_stats->{'disk_quota'},
                                                            force_units => 'MB',
                            );

    ( $user_hash->{'disk_used'}, undef )
            = Side7::Utils::File::get_formatted_filesize_from_bytes(
                                                            bytes       => $disk_stats->{'disk_usage'},
                                                            force_units => 'MB',
            );

    $user_hash->{'disk_used'} = POSIX::ceil( $user_hash->{'disk_used'} );

    $user_hash->{'disk_band1_start'} = 0;
    $user_hash->{'disk_band1_end'}   = int( $user_hash->{'disk_quota'} * .60 );
    $user_hash->{'disk_band2_start'} = $user_hash->{'disk_band1_end'};
    $user_hash->{'disk_band2_end'}   = int( $user_hash->{'disk_quota'} * .80 );
    $user_hash->{'disk_band3_start'} = $user_hash->{'disk_band2_end'};
    $user_hash->{'disk_band3_end'}   = $user_hash->{'disk_quota'};

    return $user_hash;
}


=head2 get_user_by_id()

Returns the User object for the given user_id

Parameters:

=over 4

=item user_id: The User ID to be used for the query.

=back

    my $user = Side7::User::get_user_by_id( $user_id );

=cut

sub get_user_by_id
{
    my ( $user_id ) = @_;

    return if ( ! defined $user_id || $user_id !~ /^\d+$/ );

    my $user = Side7::User->new( id => $user_id );
    my $loaded = $user->load( speculative => 1, with => [ 'account', 'user_preferences' ] );

    if ( defined $user && $loaded != 0 )
    {
        return $user;
    }

    return;
}


=head2 get_user_by_username()

Returns the User object for the given username

Parameters:

=over 4

=item username: The username to be used for the query.

=back

    my $user = Side7::User::get_user_by_username( $username );

=cut

sub get_user_by_username
{
    my ( $username ) = @_;

    return if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account', 'user_preferences' ] );

    if ( defined $user && $loaded != 0 )
    {
        return $user;
    }

    return;
}


=head2 get_users_for_directory()

Returns an array of User objects, based on the initial passed in and the page provided.

Parameters:

=over 4

=item C<initial>: the first symbol to match a name on. Defaults to 'a'

=item C<page>: the pagination segment to view. Defaults to '1'

=item C<session>: the session of the visitor. Defaults to undef

=back

    my $users = Side7::User::get_users_for_directory( initial => $initial, page => $page, session => $session );

=cut

sub get_users_for_directory
{
    my ( %args ) = @_;

    my $initial   = delete $args{'initial'}   // 'a';
    my $page      = delete $args{'page'}      // 1;
    my $session   = delete $args{'session'}   // undef;
    my $no_images = delete $args{'no_images'} // undef;

    my $initial_string = "$initial%";
    my $op = 'like';
    if ( $initial =~ m/^[^a-z0-9]+$/i )
    {
        $op = 'regexp';
        $initial_string = '^[^A-Z0-9]';
    }

    my $user_count = Side7::User::Manager->get_users_count(
        query =>
            [
                username => { $op => "$initial_string" },
            ],
    );

    my $iterator = Side7::User::Manager->get_users_iterator(
        query =>
            [
                username => { $op => "$initial_string" },
            ],
        with_objects => [ 'account', 'user_preferences', 'images', 'images.rating' ],
        sort_by      => 'username ASC',
        page         => $page,
        per_page     => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
    );

    my $users;
    while (my $user = $iterator->next)
    {
        my ( $full_name, $created_at ) = ( 'Undefined', 'Undefined' );
        if ( defined $user->account )
        {
            $full_name  = $user->account->full_name();
            $created_at = $user->account->get_formatted_created_at();
        }

        # Gather up example, random thumbnails. Max of 5.
        my @image_ids = ( List::Util::shuffle( 0 .. $#{ $user->images } ) )[ 0 .. 4 ];
        my @images = ();

        my $size = 'small';
        if ( ! defined $no_images )
        {
            foreach my $image_to_add ( @image_ids )
            {

                next if ! defined $image_to_add;

                my $image = @{ $user->images }[ $image_to_add ];

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
                        $filepath = Side7::UserContent::get_default_thumbnail_path( type => 'broken_image', size => $size );
                    }
                    else
                    {
                        if ( ! -f $filepath )
                        {
                            my $success = 0;
                            ( $success, $error ) = $image->create_cached_file( size => $size );

                            if ( $success )
                            {
                                $filepath =~ s/^\/data//;
                            }
                            else
                            {
                                $filepath = Side7::UserContent::get_default_thumbnail_path( type => 'default_image', size => $size );
                            }
                        }
                        else
                        {
                            $filepath =~ s/^\/data//;
                        }
                    }
                }

                push( @images, {
                                filepath       => $filepath,
                                filepath_error => $error,
                                uri            => "/image/$image->{'id'}",
                                title          => Side7::Utils::Text::sanitize_text_for_html( $image->title ),
                               }
                );
            }
        }

        push @$users,
            {
                user        => $user,
                image_count => $user->get_image_count(),
                images      => \@images,
            };
    }
    $iterator->finish();

    return ( $users, $user_count );
}


=head2 get_username_initials()

Returns an arrayref of the initial letters/characters for all usernames.

Parameters:

=over 4

=item None

=back

    my $initials = Side7::User::get_username_initials();

=cut

sub get_username_initials
{
    my ( $sql, $bind ) = Rose::DB::Object::QueryBuilder::build_select(
                                                            dbh     => $DB->dbh,
                                                            select  => 'DISTINCT SUBSTR(username, 1, 1) as initial',
                                                            tables  => [ 'users' ],
                                                            columns => { users => [ qw( username ) ] },
                                                            query   => [],
                                                            sort_by => 'username ASC',
                                                            query_is_sql => 1,
                                                          );

    my $sth = $DB->dbh->prepare( $sql );
    $sth->execute( @{ $bind } );

    my @initials = ();
    while ( my $row = $sth->fetchrow_hashref() )
    {
        push( @initials, uc( $row->{'initial'} ) );
    }

    $sth->finish();

    return \@initials;
}


=head2 show_user_gallery()

Returns an arrayref of Gallery content for a particular User.  Requires C<username> to be passed in.  Additional parameters control
the Content that is returned.

Parameters:

=over 4

=item username: The username used to find the User.

=item session: The session of the visitor. Defaults to undef.

=item TODO: DEFINE ADDITIONAL OPTIONAL ARGS

=back

    my $gallery = Side7::User::show_user_gallery (
        {
            username => $username,
            session  => $session,
            TODO: DEFINE ADDITIONAL OPTIONAL ARGS
        }
    );

=cut

sub show_user_gallery
{
    my ( $args ) = @_;

    my $username = delete $args->{'username'} // undef;
    my $session  = delete $args->{'session'}  // undef;

    if ( ! defined $username || $username eq '' )
    {
        $LOGGER->warn( 'No username passed into show_user_gallery.' );
        return [];
    }

    my $user = Side7::User::get_user_by_username( $username );

    if ( ! defined $user )
    {
        return;
    }

    my $gallery = $user->get_gallery( session => $session );

    return ( $user, $gallery );
}


=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2014

=cut

1;
