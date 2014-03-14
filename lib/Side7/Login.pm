package Side7::Login;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Digest::SHA1 qw(sha1);
use Digest::MD5;
use Side7::User;
use Side7::Globals;

#our $LOGGER = $Side7::Logger::LOGGER;
our $db = Side7::DB->new();

use Data::Dumper;

=pod

=head1 NAME

Side7::Login

=head1 DESCRIPTION

TODO: Define a package description.

=head1 RELATIONSHIPS

=over

=item Class::Name

This class manages the login/logout status of a user.

=back

=cut

=head1 METHODS

=head2 user_login

    $is_logged_in = Side7::Login->user_login(
                        username => $username,
                        password => $password,
                    );

Logs a user in.  If the username and password are valid, the user is logged in. If not, the login
fails. Returns a Boolean.

=cut

sub user_login
{
    my $self = shift;

    my $username = $self->param('username') // '';
    my $password = $self->param('password') // '';
    my $rd_url   = $self->param('rd_url') // 'index';

    if 
    (
        $username eq ''
        ||
        $password eq ''
    )
    {
        $self->flash( message => 'Either your username or password is incorrect. Please try again.' );
        return $self->redirect_to( 'login_form' );
    }

    my $sha1 = Digest::SHA1->new;
    $sha1->add( $password );
    my $digest = $sha1->hexdigest // '';

    my $md5_hex;
    my $crypt;

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
            $self->session( user => $user->id );
            $self->flash( message => "Welcome back, $username!" );
            return $self->redirect_to( $rd_url );
        }

        my $md5 = Digest::MD5->new;
        $md5->add( $password );
        $md5_hex = $md5->hexdigest;

        if ( $md5_hex eq $user->{'password'} )
        {
            # If the password is MD5_hex, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            $self->session( user => $user->id );
            $self->flash( message => "Welcome back, $username!" );
            return $self->redirect_to( $rd_url );
        }

        $crypt = crypt($password, 'S7');

        if ( $crypt eq $user->{'password'} )
        {
            # If the password is crypted, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            $self->session( user => $user->id );
            $self->flash( message => "Welcome back, $username!" );
            return $self->redirect_to( $rd_url );
        }

        my $result = Side7::DB::build_select(
            select  => 'OLD_PASSWORD(?) as db_pass',
            tables  => [ 'users' ],
            columns => { users => [ 'db_pass' ] },
            query   => [],
            bind    => [ $password ],
            limit   => 1,
        );
        my $db_pass = $result->[0]->{'db_pass'} // 'undefined';

        if ( $db_pass eq $user->{'password'} )
        {
            # If the password is db password, let's convert it to SHA1.
            $user->{'password'} = $digest;
            $user->save;

            $self->session( user => $user->id, username => $user->username );
            $self->flash( message => "Welcome back, $username!" );
            return $self->redirect_to( $rd_url );
        }

        $LOGGER->debug("Password compare: db - >$user->{'password'}<; di - >$digest<; md - >$md5_hex<; cr - >$crypt<; db - >$db_pass<");
    }

    # Failure
    $LOGGER->info("Login check failed: un - >$username<; pw - >$password<");
    $self->flash( message => 'Either your username or password is incorrect. Please try again.' );
    return $self->redirect_to( 'login_form' );
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

=head2 logout

    $logout = Side7::Login->logout();

Destroys the user's session cookie, and logs the user out. Redirects to the index page.

=cut

sub logout 
{
    my $self = shift;
    $self->session( expires => 1 );
    $self->redirect_to( 'index' );
}

=head2 login_form

    $output = Side7::Login->login_form();

Presents the user with a login form and any error messaging.

=cut

sub login_form
{
    my $self = shift;

    $self->render;
}

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
