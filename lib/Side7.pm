package Side7;
use Dancer ':syntax';
use Dancer::Plugin::FlashMessage;
use Dancer::Plugin::ValidateTiny;
use Dancer::Plugin::Email;
use Dancer::Plugin::DirectoryView;
use Dancer::Plugin::TimeRequests;
use Dancer::Plugin::NYTProf;

use DateTime;
use Data::Dumper;

use Side7::Globals;
use Side7::AuditLog;
use Side7::Search;
use Side7::Login;
use Side7::User;
use Side7::Account;
use Side7::UserContent::Image;
use Side7::Utils::Crypt;
use Side7::Utils::Pagination;

our $VERSION = '0.1';

hook 'before_template_render' => sub {
   my $tokens = shift;
       
   $tokens->{'css_url'}    = request->base . 'css/style.css';
   $tokens->{'login_url'}  = uri_for( '/login'  );
   $tokens->{'logout_url'} = uri_for( '/logout' );
   $tokens->{'signup_url'} = uri_for( '/signup' );
   $tokens->{'user_home_url'} = uri_for( '/my/home' );
};

get '/' => sub 
{
    template 'index';
};

# Call directory_view in a route handler
get qr{/pod_manual/(.*)} => sub {
    my ( $path ) = splat;

    # Check if the user has permissions to access these files
    return directory_view(root_dir => 'pod_manual',
                          path     => $path,
                          system_path => 1);
};

# Cached files and images
get qr{^/cached_files/(.*)} => sub {
    my ( $path ) = splat;

    send_file 'public/cached_files/' . $path;
};

###################################
### Login/Signup-related routes ###
###################################

# Login form page
get '/login' => sub
{
    params->{'rd_url'} //= vars->{'rd_url'} // undef;

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

    my ( $logged_in_url, $user, $audit_message ) = Side7::Login::user_login(
        {
            username => params->{'username'}, 
            password => params->{'password'},
            rd_url   => params->{'rd_url'}
        }
    );

    if ( defined $user && ref( $user ) eq 'Side7::User' )
    {
        session logged_in => true;
        session username  => $user->username;
        session user_id   => $user->id;
        flash message => 'Welcome back, ' . $user->username . '!';
        if ( $logged_in_url eq '/' )
        {
            $logged_in_url = '/my/home';
        }

        my $success_message = 'Login - User &gt;<b>' . $user->username . '</b>&lt; successfully logged in.';
        my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
        my $audit_log = Side7::AuditLog->new(
                                                title       => 'Successful Login',
                                                description => $success_message,
                                                ip_address  => request->address() . $remote_host,
                                                timestamp   => DateTime->now(),
        );
        $audit_log->save();

        return redirect $logged_in_url;
    }

    if ( defined $audit_message )
    {
        my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
        my $audit_log = Side7::AuditLog->new(
                                                title       => 'Invalid Login Attempt',
                                                description => $audit_message,
                                                ip_address  => request->address() . $remote_host,
                                                timestamp   => DateTime->now(),
        );
        $audit_log->save();
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

    my $confirmation_code = Side7::Utils::Crypt::sha1_hex_encode( params->{'username'} . time() );
    my $confirmation_link = uri_for( "/confirm_user/$confirmation_code" );

    # Attempt Save of new account.
    my ( $created, $errors, $user ) = Side7::User::process_signup(
        {
            username          => params->{'username'},
            email_address     => params->{'email_address'},
            password          => params->{'password'},
            birthday          => params->{'birthday'},
            confirmation_code => $confirmation_code,
        }
    );

    # If all worked, e-mail the confirmation code, and log in the user. Otherwise, error out.
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

    my $email_body = template 'email/new_user_welcome', { 
        user              => $user, 
        confirmation_link => $confirmation_link 
    }, { layout => 'email' };

    email {
        from    => 'system@side7.com',
        to      => $user->email_address,
        subject => "Welcome to Side 7, $user->username!",
        body    => $email_body,
    };

    session logged_in => true;
    session username  => $user->username;
    session user_id   => $user->id;

    my $audit_message = 'New user signup - User: &gt;<b>' . $user->username . '</b>&lt;; ';
    $audit_message   .= 'Confirmation Code: &gt;<b>' . $confirmation_code . '</b>&lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'New User Signup',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    flash message => 'Welcome to Side 7, ' . $user->username . '!';
    return redirect '/'; # TODO: This should redirect the user to a welcome/what-to-do-next page.
    
};

# New User Confirmation

get '/confirm_user/?:confirmation_code?' => sub
{
    if ( ! defined params->{'confirmation_code'} )
    {
        return template 'user/confirmation_form';
    }

    my ( $confirmed, $error ) = Side7::User::confirm_new_user( params->{'confirmation_code'} );

    if ( $confirmed == 0 )
    {
        flash error => $error;
        return template 'user/confirmation_form', { confirmation_code => params->{'confirmation_code'} };
    }

    my $audit_message = 'New user confirmation - Successful - ';
    $audit_message   .= 'Confirmation Code: &gt;<b>' . params->{'confirmation_code'} . '</b>&lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'New User Confirmation',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    template 'user/confirmed_user';
};

# New User Post-redirect to Get

post '/confirm_user' => sub
{
    return redirect '/confirm_user/' . params->{'confirmation_code'};
};

###########################
### Public-facing pages ###
###########################

# Search
get '/search/?' => sub
{
    template 'search/search_form', { look_for => params->{'look_for'} };
};

post '/search/?' => sub
{
    my $page = params->{'page'} // 1;

    my $search = Side7::Search->new();

    my ( $search_results, $search_error ) = $search->get_results( look_for => params->{'look_for'}, page=> $page );

    template 'search/search_form', { 
                                    look_for     => params->{'look_for'}, 
                                    results      => $search_results, 
                                    search_error => $search_error,
                                   };
};

# User directory.
get qr{/user_directory/?([A-Za-z0-9_]?)/?(\d*)/?} => sub
{
    my ( $initial, $page ) = splat;

    $initial ||= 'a';
    $page    ||= 1;

    my ( $users, $user_count ) = Side7::User::get_users_for_directory( { initial => $initial, page => $page } );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $user_count, page => $page } );

    template 'user/user_directory', {
                                        users      => $users, 
                                        initial    => $initial, 
                                        page       => $page, 
                                        pagination => $pagination,
                                    };
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

# User Gallery page.
get '/gallery/:username/?' => sub
{
    redirect '/user/' . params->{'username'} . '/gallery';
};

get '/user/:username/gallery/?' => sub
{
    my ( $user, $gallery ) = Side7::User::show_user_gallery( 
        { 
            username => params->{'username'},
        }
    );

    if ( ! defined $user )
    {
        redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    template 'user/show_gallery', { user => $user, gallery => $gallery };
};

# Image display page.
get '/image/:image_id/?' => sub
{
    my $image_hash = Side7::UserContent::Image::show_image( 
                        image_id => params->{'image_id'}, 
                        request  => request,
                        session  => session,
                        size     => 'large',
    );

    if ( defined $image_hash )
    {
        template 'user_content/image_details', { image => $image_hash };
    }
    else
    {
        redirect '/'; # TODO: Redirect to Image Doesn't Exist Page?
    }
};

##############################
### Pages requiring logins ###
##############################

hook 'before' => sub
{
    if ( request->path_info =~ m/^\/my\// )
    {
        if ( ! session('username') )
        {
            $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
            flash error => 'You must be logged in to view that page.';
            var rd_url => request->path_info;
            request->path_info( '/login' );
        }
        else
        {
            my $authorized = Side7::Login::user_authorization( 
                                                                session_username => session( 'username' ), 
                                                                username         => params->{'username'},
                                                             );

            if ( $authorized != 1 )
            {
                $LOGGER->info( 'User >' . session( 'username' ) . '< not authorized to view >' . request->path_info . '<' );
                flash error => 'You are not authorized to view that page.';
                return redirect '/'; # Not an authorized page.
            }
        }
    }
};

get '/my/home/?' => sub
{
    my ( $user_hash ) = Side7::User::show_home( username => session( 'username' ) );

    if ( ! defined $user_hash )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    template 'my/home', { user => $user_hash };
};

get '/my/kudos/?' => sub
{
    my ( $user_hash ) = Side7::User::show_kudos( username => session( 'username' ) );

    if ( ! defined $user_hash )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    template 'my/kudos', { user => $user_hash };
};

get '/my/permissions/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    if ( ! defined $user )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    my $permissions = $user->get_all_permissions();
    my $user_hash = {};

    template 'my/permissions', { user => $user_hash, permissions => $permissions };
};

get '/my/perks/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    if ( ! defined $user )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    my $perks = $user->get_all_perks();
    my $user_hash = {};

    template 'my/perks', { user => $user_hash, perks => $perks };
};

#############################
### Moderator/Admin pages ###
#############################

true;
