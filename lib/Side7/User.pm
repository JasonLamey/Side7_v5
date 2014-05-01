package Side7::User;

use strict;
use warnings;

use base 'Side7::DB::Object';
use List::Util;
use Data::Dumper;

use Side7::Globals;
use Side7::DataValidation;
use Side7::User::Manager;
use Side7::UserContent;
use Side7::UserContent::Image;
use Side7::User::Role;
use Side7::User::Permission;
use Side7::User::UserOwnedPermission;
use Side7::User::UserOwnedPermission::Manager;
use Side7::Utils::Crypt;
use Side7::Utils::File;

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
        user_owned_permissions =>
        {
            type       => 'one to many',
            class      => 'Side7::User::UserOwnedPermission',
            column_map => { id => 'user_id' },
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
    my $self = shift;

    my $user_hash = {};

    # User values
    foreach my $key ( qw( username email_address ) )
    {
        $user_hash->{$key} = $self->$key;
    }
    # Date values
    foreach my $key ( qw( created_at updated_at ) )
    {
        my $date = $self->$key( format => '%A, %c' );
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
        $user_hash->{$key} = $date;
    }

    # Account values (if included)
    if ( defined $self->{'account'} )
    {
        my $account = $self->{'account'}->[0];

        # General data
        $user_hash->{'account'}->{'full_name'} = $account->full_name();

        foreach my $key ( 
            qw( 
                id first_name last_name biography sex webpage_name webpage_url
                blog_name blog_url aim yahoo gtalk skype state
            )
        )
        {
            $user_hash->{'account'}->{$key} = $account->$key;
        }

        # Date values
        $user_hash->{'account'}->{'birthday'}                = $account->get_formatted_birthday();
        $user_hash->{'account'}->{'subscription_expires_on'} = $account->get_formatted_subscription_expires_on();
        $user_hash->{'account'}->{'delete_on'}               = $account->get_formatted_delete_on();
        $user_hash->{'account'}->{'created_at'}              = $account->get_formatted_created_at();
        $user_hash->{'account'}->{'updated_at'}              = $account->get_formatted_updated_at();
    }

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


=head2 get_content_directory()

Returns a string for the User's content directory on the filesystem.

    my $user_content_directory = $user->get_content_directory();

=cut

sub get_content_directory
{
    my ( $self ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return undef;
    }

    my $content_directory = $CONFIG->{'general'}->{'base_gallery_directory'} . 
            substr( $self->id, 0, 1 ) . '/' . substr( $self->id, 0, 3 ) . '/' . $self->id . '/';

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
        return undef;
    }

    my $content_uri = $CONFIG->{'general'}->{'base_gallery_uri'} .
        substr( $self->id, 0, 1 ) . '/' . substr( $self->id, 0, 3 ) . '/' . $self->id . '/';

    return $content_uri;
}


=head2 get_gallery()

Returns an arrayref of User Content belonging to the specified User.

Parameters:

=over 4

=item TODO: Additional paramters to be defined as functionality is created.

=back

    my $gallery = $user->get_gallery( { args } );

=cut

sub get_gallery
{
    my ( $self, $args ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'No User object passed in.' );
        return undef;
    }

    # TODO: BUILD OUT ADDITIONAL, OPTIONAL ARGUMENTS TO CONTROL CONTENT.
    my $gallery = Side7::UserContent::get_gallery( $self->id , {} );

    return $gallery;
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
        return undef;
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
        return undef;
    }

    my $date_format = delete $args{'date_format'} // '%A, %d %B, %Y';

    my $date = $self->updated_at( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
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
        return undef;
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
        return undef;
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

=back

    my $user_hash = Side7::User::process_signup(
                                                username          => $username,
                                                password          => $password,
                                                email_address     => $email_address,
                                                birthday          => $birthday,
                                                confirmation_code => $confirmation_code,
                                            );

=cut

sub process_signup
{
    my ( $args ) = @_;

    my $username          = delete $args->{'username'};
    my $password          = delete $args->{'password'};
    my $email_address     = delete $args->{'email_address'};
    my $birthday          = delete $args->{'birthday'};
    my $confirmation_code = delete $args->{'confirmation_code'};

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
        $LOGGER->debug( 'In Username exists check, found user: ' . (($loaded) ? 'yes' : 'no') );
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
        $LOGGER->debug( 'In Email_address exists check, found user: ' . (($loaded) ? 'yes' : 'no') );
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
        created_at    => 'now',
        updated_at    => 'now',
    );
    $user->save;

    my $account = Side7::Account->new(
        user_id             => $user->id,
        user_type_id        => 1, # Basic
        user_status_id      => 1, # Pending
        birthday            => $birthday,
        birthday_visibility => 1, # Visible
        country_id          => 228, # USA
        is_public           => 0, # Nothing is public by default
        confirmation_code   => $confirmation_code, # Used for e-mail confirmation.
        created_at          => 'now',
        updated_at          => 'now',
    );

    $user->account( $account );

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
    my $loaded = $account->load( speculative => 1 );

    if ( ! defined $account || $loaded == 0 )
    {
        $LOGGER->error( 'No matching User account for confirmation code >' . $confirmation_code . '< was found.' );
        return ( 0, 'The confirmation code >' . $confirmation_code . '< is invalid. Please check your code and try again.' );
    }

    $account->user_status_id( 2 );
    $account->confirmation_code( 'null' );
    $account->updated_at( 'now' );
    $account->save;

    my ( $success, $error ) = Side7::Utils::File::create_user_directory( $account->user_id );

    if ( ! $success )
    {
        $LOGGER->error( "Could not create User directory for ID >$account->user_id<: $error" );
    }

    return ( 1, undef );
}


=head2 show_profile()

Displays the public profile page for the given user

Parameters:

=over 4

=item username: The username for lookup for getting the user_hash for template use.

=back

    my $user_hash = Side7::User::show_profile( username => $username )

=cut

sub show_profile
{
    my ( %args ) = @_;

    my $username = delete $args{'username'};

    return undef if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return undef;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return undef;
    }

    # User Found
    my $user_hash = $user->get_user_hash_for_template();

    return $user_hash;
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

    return undef if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return undef;
    }

    # User Not Found
    if ( ! defined $user )
    {
        return undef;
    }

    my $user_hash = $user->get_user_hash_for_template();

    return ( $user_hash );
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

    return undef if ( ! defined $user_id || $user_id !~ /^\d+$/ );

    my $user = Side7::User->new( id => $user_id );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( defined $user && $loaded != 0 )
    {
        return $user;
    }

    return undef;
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

    return undef if ( ! defined $username || $username eq '' );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( defined $user && $loaded != 0 )
    {
        return $user;
    }

    return undef;
}


=head2 get_users_for_directory()

Returns an array of User objects, based on the initial passed in and the page provided.

Parameters:

=over 4

=item C<initial>: the first symbol to match a name on. Defaults to 'a'

=item C<page>: the pagination segment to view. Defaults to '1'

=back

    my $users = Side7::User::get_users_for_directory( { initial => $initial, page => $page } );

=cut

sub get_users_for_directory
{
    my ( $args ) = @_;

    my $initial = delete $args->{'initial'} // 'a';
    my $page    = delete $args->{'page'}    // 1;

    my $initial_string = "$initial%";
    my $op = 'like';
    if ( $initial eq '_' )
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
        with_objects => [ 'account', 'images' ],
        sort_by      => 'username ASC',
        page         => $page,
        per_page     => $CONFIG->{'page'}->{'user_directory'}->{'pagination_limit'},
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
        foreach my $image_to_add ( @image_ids )
        {

            next if ! defined $image_to_add;

            my $image = @{ $user->images }[ $image_to_add ];

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
            
            push( @images, { filepath => $filepath, filepath_error => $error, uri => "/image/$image->{'id'}" } );
        }

        push @$users, 
            {
                id            => $user->id,
                username      => $user->username,
                full_name     => $full_name,
                join_date     => $created_at,
                image_count   => $user->get_image_count(),
                images        => \@images,
            };
    }
    $iterator->finish();

    return ( $users, $user_count );
}


=head2 show_user_gallery()

Returns an arrayref of Gallery content for a particular User.  Requires C<username> to be passed in.  Additional parameters control
the Content that is returned.

Parameters:

=over 4

=item username: The username used to find the User.

=item TODO: DEFINE ADDITIONAL OPTIONAL ARGS

=back

    my $gallery = Side7::User::show_user_gallery (
        {
            username = $username,
            TODO: DEFINE ADDITIONAL OPTIONAL ARGS
        }
    );

=cut

sub show_user_gallery
{
    my ( $args ) = @_;

    my $username = delete $args->{'username'};

    if ( ! defined $username || $username eq '' )
    {
        $LOGGER->warn( 'No username passed into show_user_gallery.' );
        return [];
    }

    my $user = Side7::User::get_user_by_username( $username );

    if ( ! defined $user )
    {
        return undef; # TODO: Need to redirect to invalid user error page.
    }

    my $gallery = $user->get_gallery();

    return ( $user, $gallery );
}


=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2014

=cut

1;
