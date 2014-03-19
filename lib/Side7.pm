package Side7;
use Dancer ':syntax';
use Dancer::Plugin::FlashMessage;
use Dancer::Plugin::ValidateTiny;
use Data::Dumper;

use Side7::Globals;
use Side7::User;
use Side7::Account;
use Side7::Login;

our $VERSION = '0.1';

hook 'before_template_render' => sub {
   my $tokens = shift;
       
   $tokens->{'css_url'} = request->base . 'css/style.css';
   $tokens->{'login_url'} = uri_for('/login');
   $tokens->{'logout_url'} = uri_for('/logout');
   $tokens->{'signup_url'} = uri_for('/signup');
};

get '/' => sub 
{
    template 'index';
};

# Login-related routes

# Login form page
get '/login' => sub
{
    my $rd_url = Side7::Login::sanitize_redirect_url( 
        { 
            rd_url   => params->{'rd_url'}, 
            referer  => request->referer,
            uri_base => request->uri_base
        } 
    );

    template 'login/login_form', { rd_url => $rd_url };
};

# Login user action
post '/login' => sub
{
    if (
        ! defined params->{'username'}
        ||
        ! defined params->{'password'}
    )
    {
        flash error => "Both Username and Password are required.";
        return template 'login/login_form', { rd_url => params->{'rd_url'} };
    }

    my ( $logged_in_url, $user ) = Side7::Login::user_login(
        {
            username => params->{'username'}, 
            password => params->{'password'},
            rd_url   => params->{'rd_url'}
        }
    );

    if ( defined $logged_in_url && $logged_in_url ne '' )
    {
        session logged_in => true;
        session username  => $user->username;
        session user_id   => $user->id;
        flash message => 'Welcome back, ' . $user->username . '!';
        return redirect $logged_in_url;
    }

    flash error => 'Either your Username or your Password (or both) is incorrect.';
    return template 'login/login_form', { username => params->{'username'}, rd_url => params->{'rd_url'} };
};

# Logout user action
get '/logout' => sub
{
    session->destroy;
    flash message => 'You have been logged out.';
    redirect '/';
};

# Sign up new user form
get '/signup' => sub
{
    template 'user/signup_form';
};

# Sign up new user action
post '/signup' => sub
{
    my $params = params;
    my $is_data_valid = 0;
 
    # Validating params with rule file
    my $data = validator( $params, 'signup_form.pl' );

    if ( ! $data->{'valid'} )
    {
        my $err_message = "You have errors that need to be corrected:<br />";
        foreach my $key ( sort keys %{$data->{'result'}} )
        {
            if ( $key =~ m/^err_/ )
            {
                $err_message .= "$data->{'result'}->{$key}<br />";
            }
        }
        $err_message =~ s/<br \/>$//;
        flash error => $err_message;
        return template 'user/signup_form', { 
            username      => params->{'username'}, 
            email_address => params->{'email_address'},
            birthday      => params->{'birthday'},
        };
    }

    # Attempt Save of new account.
    my ( $created, $errors, $user ) = Side7::User::process_signup(
        {
            username      => params->{'username'},
            email_address => params->{'email_address'},
            password      => params->{'password'},
            birthday      => params->{'birthday'},
        }
    );

    # If all worked, log in the user. Otherwise, error out.
    if ( $created < 1 )
    {
        my $err_message = 'You have errors that need to be corrected:<br />';
        foreach my $msg ( @{$errors} )
        {
            $err_message .= $msg . '<br />';
        }

        $err_message =~ s/<br \/>$//;
        flash error => $err_message;
        return template 'user/signup_form', { 
            username      => params->{'username'}, 
            email_address => params->{'email_address'},
            birthday      => params->{'birthday'},
        };
    }

    session logged_in => true;
    session username  => $user->username;
    session user_id   => $user->id;
    flash message => 'Welcome to Side 7, ' . $user->username . '!';
    return redirect '/'; # TODO: This should redirect the user to a welcome/what-to-do-next page.
    
};

# Public-facing pages

# User directory.
get qr{/user_directory/?([A-Za-z0-9_]?)/?(\d*)/?} => sub
{
    my ( $initial, $page ) = splat;

    $initial ||= 'a';
    $page    ||= 1;

    my $users = Side7::User::get_users_for_directory( { initial => $initial, page => $page } );
    template 'user/user_directory', { users => $users, initial => $initial, page => $page };
};

# User profile page.
get '/user/:username' => sub
{
    my $user_hash = Side7::User::show_profile( username => params->{'username'} );

    if ( defined $user_hash )
    {
        template 'user/show_user_profile', { user => $user_hash };
    }
    else
    {
        redirect '/';
    }
};

# Pages requiring logins

# Moderator/Admin pages

true;
