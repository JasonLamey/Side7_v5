package Side7::Login;

use strict;
use warnings;

use Dancer qw( :syntax );
use Data::Dumper;

use Side7::Globals;
use Side7::User;


=pod

=head1 NAME

Side7::Login

=head1 DESCRIPTION

This class manages the login/logout status of a user.

=head1 FUNCTIONS

=head2 user_login

    my ( $redirect_url, $user_object ) = Side7::Login::user_login(
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

    $LOGGER->debug( 'rd_url: >' . $rd_url . '<' );

    if 
    (
        $username eq ''
        ||
        $password eq ''
    )
    {
        $LOGGER->warn('No username or password given from login_form.');
        return undef;
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
            $LOGGER->debug( 'SHA1 matched.' );
            return ( $rd_url, $user );
        }

        my $md5_hex = Side7::Utils::Crypt::md5_hex_encode( $password );

        if ( $md5_hex eq $user->{'password'} )
        {
            # If the password is MD5_hex, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            return ( $rd_url, $user );
        }

        my $crypt = Side7::Utils::Crypt::old_side7_crypt( $password );

        if ( $crypt eq $user->{'password'} )
        {
            # If the password is crypted, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            return ( $rd_url, $user );
        }

        my $db_pass = Side7::Utils::Crypt::old_mysql_password( $password );

        if ( $db_pass eq $user->{'password'} )
        {
            # If the password is db password, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            return ( $rd_url, $user );
        }

        $LOGGER->debug( "Password compare: db - >$user->{'password'}<; di - >$digest<; md - >$md5_hex<; cr - >$crypt<; db - >$db_pass<" );
    }

    # Failure
    $LOGGER->info("Login check failed: un - >$username<; pw - >$password<");
    return undef;
}

=head2 is_logged_in

    $is_logged_in = Side7::Login->is_logged_in();

Returns the user's session cookie if the user is logged in.  Redirects to the index page otherwise.

=cut

sub is_logged_in
{
    my $self = shift;
    return $self->session( 'user' ) || ! $self->redirect_to( 'index' );
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


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
