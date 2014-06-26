package Side7::Login;

use strict;
use warnings;

use Dancer qw( :syntax );
use Data::Dumper;

use Side7::Globals;
use Side7::AuditLog;
use Side7::User;


=pod


=head1 NAME

Side7::Login


=head1 DESCRIPTION

This class manages the login/logout status of a user.


=head1 FUNCTIONS


=head2 user_login

    my ( $redirect_url, $user_object, $audit_log_msg ) = Side7::Login::user_login(
                        username => $username,
                        password => $password,
                        rd_url   => $rd_url,
                    );

Logs a user in.  If the username and password are valid, the user is logged in. If not, the login
fails. Returns a redirect path, and the user object if the user is logged in.

=cut

sub user_login
{
    my ( $args ) = @_;

    my $username = delete $args->{'username'};
    my $password = delete $args->{'password'};
    my $rd_url   = delete $args->{'rd_url'};

    $rd_url ||= '/'; # Set default redirect path to root, so we don't return to the login screen.

    if 
    (
        $username eq ''
        ||
        $password eq ''
    )
    {
        $LOGGER->warn('No username or password given from login_form.');
        return ( $rd_url, undef, 'Error - No username or password provided.' );
    }

    my $digest = Side7::Utils::Crypt::sha1_hex_encode( $password );

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1 );

    # Provided that we returned a proper User, we can try comparing the
    # password. New or recently logged in accounts will be in SHA1,
    # migrated accounts will have passwords in crypt.  We will convert
    # MD5 and crypt'ed passwords to SHA1 on their first login for more security.
    if ( ref($user) eq 'Side7::User' && $loaded != 0 )
    {
        if ( $digest eq $user->{'password'} )
        {
            return ( $rd_url, $user, undef );
        }

        my $md5_hex = Side7::Utils::Crypt::md5_hex_encode( $password );

        if ( $md5_hex eq $user->{'password'} )
        {
            # If the password is MD5_hex, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            return ( $rd_url, $user, undef );
        }

        my $crypt = Side7::Utils::Crypt::old_side7_crypt( $password );

        if ( $crypt eq $user->{'password'} )
        {
            # If the password is crypted, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            return ( $rd_url, $user, undef );
        }

        my $db_pass = Side7::Utils::Crypt::old_mysql_password( $password );

        if ( $db_pass eq $user->{'password'} )
        {
            # If the password is db password, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            return ( $rd_url, $user, undef );
        }

        #$LOGGER->debug( "Password compare: db - >$user->{'password'}<; di - >$digest<; md - >$md5_hex<; cr - >$crypt<; db - >$db_pass<" );
    }
    else
    {
        # Invalid User
        $LOGGER->error( "User >$username< doesn't exist in the database." );
        return ( $rd_url, undef, "Invalid login attempt - User &gt;<b>$username</b>&lt; doesn't exist in the database." );
    }

    # Failure
    my $error = 'Invalid login attempt - Bad username/password combo - Username: &gt;<b>' . $username . '</b>&lt;; ';
    $error   .= 'Password: &gt;<b>' . $password . '</b>&lt; ';
    $error   .= 'RD_URL: &gt;<b>' . $rd_url  . '</b>&lt;';

    $LOGGER->info("Login check failed: un - >$username<; pw - >$password<");
    return ( $rd_url, undef, $error );
}


=head2 sanitize_redirect_url

    my $rd_url = Side7::Login::sanitize_redirect_url(
        { rd_url => params->{'rd_url'}, referer => request->referer, uri_base => request->uri_base }
    );

Cleans up any redirect URL intended to be passed to the login_form, and ensures that (a) it's not from outside
the site, and (b) it's cleaned up and has the domain removed.

=cut

sub sanitize_redirect_url
{

    my ( $args ) = @_;

    my $rd_url   = delete $args->{'rd_url'};
    my $referer  = delete $args->{'referer'};
    my $uri_base = delete $args->{'uri_base'};

    my $redirect_url = '/';

    if ( defined $rd_url )
    {
        # If we were passed an rd_url, let's strip off the domain name, regardless of what it is.
        $rd_url =~ s|^https?://[^/]+/?\??|/|;
        $redirect_url = $rd_url;
    }
    elsif ( defined $referer )
    {
        # Let's ensure that the referer is from within our domain. If it isn't we're not going to use it.
        if ( $referer =~ m/$uri_base/ )
        {
            $referer =~ s/$uri_base//;
            $redirect_url = $referer;
        }
    }

    return $redirect_url;
}


=head2 user_authorization()

    my $is_authorized = Side7::Login::user_authorization( session_username => session('username'), username = params->{'username'} );

Returns a boolean if the User is both logged in, and attempting to access a page that belongs to the User.
Attempts to access pages that require being logged in, or accessing a page that doesn't belong to the User,
will result in the return of a false value.

=cut

sub user_authorization
{
    my ( %args ) = @_;

    my $session_username = delete $args{'session_username'} // undef;
    my $username         = delete $args{'username'}         // undef;
    my $requires_admin   = delete $args{'requires_admin'}   // undef;
    my $requires_mod     = delete $args{'requires_mod'}     // undef;

    return 0 if ! defined $session_username;

    if ( defined $username )
    {
        return 0 if ( uc( $session_username ) ne uc( $username ) );
    }

    my $user = undef;
    my $user_role = undef;
    if ( defined $requires_mod || defined $requires_admin )
    {
        $user      = Side7::User::get_user_by_username( $session_username );
        $user_role = $user->account->user_role->name();
    }

    if ( defined $requires_mod )
    {
        if
        ( 
            $user_role ne 'Moderator'
            &&
            $user_role ne 'Admin'
            &&
            $user_role ne 'Owner'
        )
        {
            return 0;
        }
    }

    if ( defined $requires_admin )
    {
        if
        ( 
            $user_role ne 'Admin'
            &&
            $user_role ne 'Owner'
        )
        {
            return 0;
        }
    }

    return 1;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
