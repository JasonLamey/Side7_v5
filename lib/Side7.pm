package Side7;
use Dancer ':syntax';

use Side7::Globals;
use Side7::User;
use Side7::Account;

our $VERSION = '0.1';

get '/' => sub 
{
    template 'index';
};

# Login-related routes

# Login form page
get '/login' => sub
{
};

# Login user action
put '/login' => sub
{
};

# Logout user action
get '/logout' => sub
{
};

# Public-facing pages

# User profile page.
get '/user/:username' => sub
{
    my $user_hash = Side7::User::show_profile( username => params->{'username'} );

    if ( defined $user_hash )
    {
        return template 'user/show_user_profile', { user => $user_hash };
    }
    else
    {
        return redirect '/';
    }
};

# Pages requiring logins

# Moderator/Admin pages

true;
