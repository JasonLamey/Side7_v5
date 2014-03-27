package Side7::User;

use strict;
use warnings;

use base 'Side7::DB::Object';
use Data::Dumper;

use Side7::Globals;
use Side7::DataValidation;
use Side7::User::Manager;
use Side7::UserContent::Image;
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
    ],
);


=head1 METHODS


=head2 get_user_hash_for_template()

    $user_hash = $user->get_user_hash_for_template();

=over 4

=item Takes User object and converts it and its associated Account object (if embedded) into an easily accessible hash to pass to the templates.  Additionally, it formats the associated dates properly for output.

=back

=cut

sub get_user_hash_for_template
{
    my $self = shift;

    my $user_hash;

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

    my $image_count = $user->get_image_count();

Returns the total number of images for a given user.

=cut

sub get_image_count
{
    my ( $self ) = @_;

    return Side7::UserContent::Image::Manager->get_images_count(
        query => [
            user_id => [ $self->id ],
        ],
    );
}


=head2 get_content_directory()
    my $user_content_directory = $user->get_content_directory();

Returns a string for the User's content directory on the filesystem.

=cut

sub get_content_directory
{
    my ( $self ) = @_;

    my $content_directory = $CONFIG->{'general'}->{'base_gallery_directory'} . 
            substr( $self->id, 0, 1 ) . '/' . substr( $self->id, 0, 3 ) . '/' . $self->id . '/';

    return $content_directory;
}


=head2 get_content_uri()
    my $user_content_uri = $user->get_content_uri();

Returns a string for the User's content URI. This is different from get_content_directory as it's relative
to the domain, not to the filesystem.

=cut

sub get_content_uri
{
    my ( $self ) = @_;

    my $content_uri = $CONFIG->{'general'}->{'base_gallery_uri'} .
        substr( $self->id, 0, 1 ) . '/' . substr( $self->id, 0, 3 ) . '/' . $self->id . '/';

    return $content_uri;
}


=head1 FUNCTIONS


=head2 process_signup()

    $user_hash = Side7::User::process_signup();

=over 4

=item Takes user sign-up information and performs some safety checks with it.  Then it creates a User object, and saves it to the database.

=back

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
    my @form_errors;

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

    my ( $confirmed, $error ) = Side7::User::confirm_new_user( $confirmation_code );

=over 4

=item Checks for a User account that has the confirmation_code that is passed in. If so, updates the User's status from 'Pending' to 'Active'. Creates the User's directory structure.

=back

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


=head2 check_user_existence()

    $user = Side7::User::check_user_existence( $user_id )

=over 4

=item Checks to see if the user exists, and pushes the user to the stash and returns true if found. If not found, returns undef.

=back

=cut

sub check_user_existence
{
    my $self = shift;

    # Fetch the username out of the path
    my $username = $self->req->url->path;
    $username =~ s/^\/user\///i;
    $username =~ s/\/.*$//i;
    $LOGGER->debug( 'Username: ' . $username );

    return undef if ! defined $username || $username eq '';

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( defined $user && $loaded != 0 )
    {
        $self->stash( user => $user );
        $LOGGER->debug( 'Pre-stash: ' . Dumper( $self->stash( 'user' ) ) );
        return 1;
    }

    # TODO: Redirect to index? Or User Not Found page?
    return undef;
}


=head2 show_profile()

    Side7::User::show_profile()

=over 4

=item Displays the public profile page for the given user

=back

=cut

sub show_profile
{
    my ( %args ) = @_;

    my $username = delete $args{'username'};

    return undef if ( ! defined $username );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1, with => [ 'account' ] );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not find user >' . $username . '< in database.' );
        return undef;
    }

    # User Found
    if ( defined $user )
    {
        my $user_hash = $user->get_user_hash_for_template();
        return $user_hash;
    }

    # User Not Found
    # TODO: Redirect to a user_not_found template instead of 404?
    return undef;
}


=head2 get_user()

    $user = Side7::User::get_user( $user_id )

=over 4

=item Returns the User object for the given user_id

=back

=cut

sub get_user
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

=head2 get_users_for_directory()

    my $users = Side7::User::get_users_for_directory( { initial => $initial, page => $page } );

=over 4

=item Returns an array of User objects, based on the initial passed in and the page provided.

=back

Takes two optional variables:
initial (the first symbol to match a name on), and page (the pagination segment to view).
Initial defaults to 'a', page defaults to '1'.

=cut

sub get_users_for_directory
{
    my ( $args ) = @_;

    my $initial = delete $args->{'initial'};
    my $page    = delete $args->{'page'};

    $initial //= 'a';
    $page    //= 1;

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

    my $offset = ( ( $page - 1 ) * $CONFIG->{'page'}->{'user_directory'}->{'pagination_limit'} );

    my $iterator = Side7::User::Manager->get_users_iterator(
        query => 
            [ 
                username => { $op => "$initial_string" },
            ],
        with_objects => [ 'account' ],
        sort_by => 'username ASC',
        limit   => $CONFIG->{'page'}->{'user_directory'}->{'pagination_limit'},
        offset  => $offset,
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
        push @$users, 
            {
                id            => $user->id,
                username      => $user->username,
                full_name     => $full_name,
                join_date     => $created_at,
                image_count   => $user->get_image_count(),
            };
    }
    $iterator->finish();

    return ( $users, $user_count );
}


=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2014

=cut

1;
