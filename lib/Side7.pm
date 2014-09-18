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
use Const::Fast;

use Side7::Globals;
use Side7::AuditLog;
use Side7::Search;
use Side7::Login;
use Side7::News::Manager;
use Side7::User;
use Side7::User::ChangePassword;
use Side7::User::AccountDelete;
use Side7::DateVisibility::Manager;
use Side7::Account;
use Side7::UserContent::Image;
use Side7::UserContent::RatingQualifier;
use Side7::Utils::Crypt;
use Side7::Utils::Pagination;
use Side7::Utils::Image;
use Side7::FAQCategory;
use Side7::FAQCategory::Manager;
use Side7::FAQEntry;

our $VERSION = '0.1';
const my $AGE_18_IN_MONTHS => 216;

hook 'before_template_render' => sub {
   my $tokens = shift;
       
   $tokens->{'css_url'}    = request->base . 'css/style.css';
   $tokens->{'login_url'}  = uri_for( '/login'  );
   $tokens->{'logout_url'} = uri_for( '/logout' );
   $tokens->{'signup_url'} = uri_for( '/signup' );
   $tokens->{'user_home_url'} = uri_for( '/my/home' );
};

hook 'before' => sub {

    # Setting Visitor-relavent user preferences.
    my $visitor = undef;
    if ( defined session( 'logged_in' ) ) {
        $visitor = 
            Side7::User->new( id => session( 'user_id' ) )->load( speculative => 1, with => [ 'user_preferences' ] );
        foreach my $key ( 
                            qw/ display_signature show_management_thumbs show_m_thumbs show_adult_content
                                filter_profanity thumbnail_size content_display_type display_full_sized_images /
                        )
        {
            var $key => $visitor->user_preferences->$key;
        }
    }
    else
    {
        # Default 0
        foreach my $key ( qw/ display_signature show_m_thumbs show_adult_content / )
        {
            var $key => 0;
        }

        # Default 1
        foreach my $key ( qw/ show_management_thumbs filter_profanity / )
        {
            var $key => 1;
        }

        # Specific Defaults
        var thumbnail_size            => 'Small';
        var content_display_type      => 'List';
        var display_full_sized_images => 'Same Window';
    }


    set layout => 'main';
};

get '/' => sub 
{
    my $stickies = Side7::News::Manager->get_news(
                                                    query => [
                                                                is_static        => 1,
                                                                not_static_after => { ge => DateTime->today() },
                                                             ],
                                                    with_objects => [ 'user' ],
                                                    sort_by      => 'created_at DESC',
                                                    limit        => 5,
                                                  );

    my $results = Side7::News::Manager->get_news(
                                                    query   => [
                                                                    is_static => 0,
                                                               ],
                                                    with_objects => [ 'user' ],
                                                    sort_by      => 'created_at DESC',
                                                    limit        => 5,
                                                );

    # Get News Hashes
    my $news = [];
    foreach my $result ( @$results )
    {
        push( @$news, $result->get_news_hash_for_template() );
    }

    my $sticky_news = [];
    foreach my $sticky ( @$stickies )
    {
        push( @$sticky_news, $sticky->get_news_hash_for_template() );
    }

    template 'index', {
                        data => {
                                    news        => $news,
                                    sticky_news => $sticky_news,
                                },
                      }, { layout => 'index' };
};

# News Directory Page
get '/news/?:page?' => sub
{
    my $page = params->{'page'} // 1;

    my $news = Side7::News->get_news_article_list( page => $page );
    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $news->{'news_count'}, page => $page } );

    template 'news/article_list', { 
                                    data          => $news, 
                                    page          => $page,
                                    pagination    => $pagination,
                                    link_base_uri => '/news',
                                  };
};

# News Article Page
get '/news/article/:news_id' => sub
{
    my $news_id = params->{'news_id'} // undef;

    if ( ! defined $news_id )
    {
        flash error => 'Invalid News ID';
        return redirect '/news';
    }

    my $news_item = Side7::News->get_news_article( news_id => $news_id );

    if ( scalar( keys %$news_item ) == 0 )
    {
        flash error => 'Invalid News ID';
        return redirect '/news';
    }

    template 'news/article', { 
                                 data => $news_item, 
                             };
};

# Call directory_view in a route handler
get qr{/pod_manual/(.*)} => sub {
    my ( $path ) = splat;

    # Check if the user has permissions to access these files
    return directory_view(root_dir => 'pod_manual',
                          path     => $path,
                          system_path => 1);
};

# Font files for CSS.
get qr{^/fonts/(.*)} => sub {
    my ( $path ) = splat;

    send_file 'public/fonts/' . $path;
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
            referred_by   => params->{'referred_by'},
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
            referred_by       => params->{'referred_by'},
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
            referred_by   => params->{'referred_by'},
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

    my $audit_message = 'New user confirmation - <b>Successful</b> - ';
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

# Progress Bar
#get '/progress_bar' => sub {
#    long_running 'progress_bar', 5, sub {
#        my $state = shift;
# 
#        $state->{timer} =
#        AnyEvent->timer(after => 1, interval => 1, cb => sub {
#            if (++$state->{cnt} == 5) {
#                undef $state->{timer};
#                finished 'progress_bar';
#            } else {
#                progress 'progress_bar' => $state->{cnt};
#            }
#        });
#    };
# 
#    template 'progressbar', { name => 'progress_bar' };
#};

# Search
get '/search/?' => sub
{
    template 'search/search_form', { look_for => params->{'look_for'} };
};

post '/search/?' => sub
{
    my $page = params->{'page'} // 1;

    my $search = Side7::Search->new();

    my ( $search_results, $search_error ) = $search->get_results(
                                                                    look_for         => params->{'look_for'}, 
                                                                    page             => $page,
                                                                    filter_profanity => vars->{'filter_profanity'},
                                                                );

    template 'search/search_form', { 
                                    look_for     => params->{'look_for'}, 
                                    results      => $search_results, 
                                    search_error => $search_error,
                                   };
};

# FAQ routes.
get '/faq/?:category_id?/?:entry_id?/?' => sub
{
    if
    (
        defined params->{'category_id'}
        &&
        defined params->{'entry_id'}
    )
    {
        # FAQ Entry Permalink
        my $category   = Side7::FAQCategory->new( id => params->{'category_id'} );
        my $cat_loaded = $category->load( speculative => 1 );

        if ( $cat_loaded == 0 )
        {
            flash error => 'That is not a valid FAQ Category';
            return redirect '/faq';
        }

        my $entry = Side7::FAQEntry->new( id => params->{'entry_id'} );
        my $ent_loaded = $entry->load( speculative => 1 );

        if ( $ent_loaded == 0 )
        {
            flash error => 'That is not a valid FAQ Entry';
            return redirect '/faq';
        }

        return template 'faq', { category => $category, entry => $entry };
    }
    elsif
    (
        defined params->{'category_id'}
        &&
        ! defined params->{'entry_id'}
    )
    {
        # FAQ Category Page
        my $category   = Side7::FAQCategory->new( id => params->{'category_id'} );
        my $cat_loaded = $category->load( speculative => 1, with => [ 'faq_entries' ] );

        if ( $cat_loaded == 0 )
        {
            flash error => 'That is not a valid FAQ Category';
            return redirect '/faq';
        }

        my @entries = sort { $a->{'priority'} <=> $b->{'priority'} } ( @{ ( $category->{'faq_entries'} // [] ) } );

        return template 'faq', { category => $category, entries => \@entries };
    }
    else
    {
        # FAQ General Page
        my $categories = Side7::FAQCategory::Manager->get_faq_categories( sort_by => 'priority ASC' );

        return template 'faq', { categories => $categories };
    }
};

# User directory.
get qr{/user_directory/?([A-Za-z0-9_]?)/?(\d*)/?} => sub
{
    my ( $initial, $page ) = splat;

    if ( ! defined $initial || $initial eq '' )
    {
        $initial = 'a';
    }

    if ( ! defined $page || $page eq '' )
    {
        $page = 1;
    }

    my $initials = Side7::User::get_username_initials();

    my ( $users, $user_count ) = Side7::User::get_users_for_directory( initial => $initial, page => $page, session => session );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $user_count, page => $page } );

    template 'user/user_directory', {
                                        data          => { 
                                                            initials   => $initials,
                                                            users      => $users, 
                                                            user_count => $user_count,
                                                         },
                                        initial       => $initial, 
                                        page          => $page, 
                                        pagination    => $pagination,
                                        link_base_uri => '/user_directory',
                                    };
};

# User profile page.
get '/user/:username' => sub
{
    my $user_hash = Side7::User::show_profile( 
                                                username => params->{'username'}, 
                                                filter_profanity => vars->{'filter_profanity'},
                                             );

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
            session  => session,
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
                                                            size             => 'large',
                                                            request          => request,
                                                            session          => session,
                                                            filter_profanity => vars->{'filter_profanity'},
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

            set layout => 'my';
        }
    }
};

# User Home Page
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

# User Account Management Landing Page
get '/my/account/?' => sub
{
    my ( $user_hash ) = Side7::User::show_account( username => session( 'username' ) );

    if ( ! defined $user_hash )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    template 'my/account', { user => $user_hash };
};

# User Change Password Step 1
post '/my/changepassword/?' => sub
{
    my $params = params;
 
    # Validating params with rule file
    my $data = validator( $params, 'change_password_form.pl' );

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
        return redirect '/my/account';
    }

    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my ( $success, $error ) = $user->is_valid_password( params->{'old_password'} );

    if ( $success == 0 )
    {
        my $err_message = "You have errors that need to be corrected:<br />";
        $err_message .= "Your Current Password is incorrect: $error";

        flash error => $err_message;
        return redirect '/my/account';
    }

    my $user_hash = $user->get_user_hash_for_template();

    my $confirmation_code = Side7::Utils::Crypt::sha1_hex_encode( session( 'username' ) . time() );
    my $confirmation_link = uri_for( "/my/confirm_password_change/$confirmation_code" );

    # Record change to be made in a temp record
    my $password_change = Side7::User::ChangePassword->new(
                                                            user_id           => session( 'user_id' ),
                                                            confirmation_code => $confirmation_code,
                                                            new_password      => params->{'new_password'},
                                                            created_at        => 'now',
                                                            updated_at        => 'now',
                                                          );

    $password_change->save();

    # Send e-mail to User with a confirmation link
    my $email_body = template 'email/password_change_confirmation', { 
        user              => $user, 
        confirmation_link => $confirmation_link 
    }, { layout => 'email' };

    email {
        from    => 'system@side7.com',
        to      => $user->email_address,
        subject => "Password change on Side 7, $user->username!",
        body    => $email_body,
    };

    my $audit_message = 'Password Change Request Sent - ';
    $audit_message   .= 'User: &gt;<b>' . session( 'username' ) . '</b>&lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Password Change Request',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          user_id     => session( 'user_id' ),
                                          affected_id => session( 'user_id' ),
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    # Display page with instructions to the User
    return template 'my/password_change_next_step', { user => $user_hash };
};

# User Change Password Step 2
get '/my/confirm_password_change/?:confirmation_code?' => sub
{
    if ( ! defined params->{'confirmation_code'} )
    {
        return template 'my/change_password_confirmation_form';
    }

    my $change_result = Side7::User::confirm_password_change( params->{'confirmation_code'} );

    if
    (
        ! defined $change_result->{'confirmed'}
        ||
        $change_result->{'confirmed'} == 0
    )
    {
        flash error => $change_result->{'error'};
        return template 'my/change_password_confirmation_form',
                                    { confirmation_code => params->{'confirmation_code'} };
    }

    my $audit_message = 'Password Change confirmation - <b>Successful</b> - ';
    $audit_message   .= 'Confirmation Code: &gt;<b>' . params->{'confirmation_code'} . '</b>&lt; - ';
    $audit_message   .= 'Original value: &gt;<b>' . $change_result->{'original_password'} . '</b>%lt; - ';
    $audit_message   .= 'New value: &gt;<b>' . $change_result->{'new_password'} . '</b>%lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Password Change Confirmation',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          user_id     => session( 'user_id' ),
                                          affected_id => session( 'user_id' ),
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    template 'my/password_change_confirmed';
};

# User Change Password Post-redirect to Get
post '/my/confirm_password_change' => sub
{
    return redirect '/my/confirm_password_change/' . params->{'confirmation_code'};
};

# User Set Delete Flag Step 1
post '/my/setdelete/?' => sub
{
    my $params = params;
 
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $user_hash = $user->get_user_hash_for_template();

    my $confirmation_code = Side7::Utils::Crypt::sha1_hex_encode( session( 'username' ) . time() );
    my $confirmation_link = uri_for( "/my/confirm_set_delete/$confirmation_code" );

    # Record change to be made in a temp record
    my $set_delete = Side7::User::AccountDelete->new(
                                                        user_id           => session( 'user_id' ),
                                                        confirmation_code => $confirmation_code,
                                                        created_at        => 'now',
                                                        updated_at        => 'now',
                                                    );

    $set_delete->save();

    # Send e-mail to User with a confirmation link
    my $email_body = template 'email/set_account_delete_flag_confirmation', { 
        user              => $user, 
        confirmation_link => $confirmation_link 
    }, { layout => 'email' };

    email {
        from    => 'system@side7.com',
        to      => $user->email_address,
        subject => "Setting Your Account For Deletion From Side 7, $user->username!",
        body    => $email_body,
    };

    my $audit_message = 'Set Account Delete Flag Request Sent - ';
    $audit_message   .= 'User: &gt;<b>' . session( 'username' ) . '</b>&lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Set Delete Flag Request',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          user_id     => session( 'user_id' ),
                                          affected_id => session( 'user_id' ),
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    # Display page with instructions to the User
    return template 'my/set_delete_flag_next_step', { user => $user_hash };
};

# User Set Delete Flag Step 2
get '/my/confirm_set_delete_flag/?:confirmation_code?' => sub
{
    if ( ! defined params->{'confirmation_code'} )
    {
        return template 'my/set_delete_flag_confirmation_form';
    }

    my $change_result = Side7::User::confirm_set_delete_flag( params->{'confirmation_code'} );

    if
    (
        ! defined $change_result->{'confirmed'}
        ||
        $change_result->{'confirmed'} == 0
    )
    {
        flash error => $change_result->{'error'};
        return template 'my/set_delete_flag_confirmation_form',
                                    { confirmation_code => params->{'confirmation_code'} };
    }

    my $audit_message = 'Set Delete Flag confirmation - <b>Successful</b> - ';
    $audit_message   .= 'Confirmation Code: &gt;<b>' . params->{'confirmation_code'} . '</b>&lt; - ';
    $audit_message   .= 'Delete On: &gt;<b>' . $change_result->{'delete_on'} . '</b>%lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Set Delete Flag Confirmation',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          user_id     => session( 'user_id' ),
                                          affected_id => session( 'user_id' ),
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    template 'my/set_delete_flag_confirmed', { delete_on => $change_result->{'delete_on'} };
};

# User Set Delete Flag Post-redirect to Get
post '/my/confirm_set_delete_flag' => sub
{
    return redirect '/my/confirm_set_delete_flag/' . params->{'confirmation_code'};
};

# Remove Delete Flag from account.
post '/my/cleardelete' => sub
{
    my $change_result = Side7::User::clear_delete_flag( session( 'username' ) );
    if
    (
        ! defined $change_result->{'cleared'}
        ||
        $change_result->{'cleared'} == 0
    )
    {
        flash error => $change_result->{'error'};
        return template 'my/account';
    }

    my $audit_message = 'Delete Flag Removal - <b>Successful</b>';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Cleared Delete Flag',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          user_id     => session( 'user_id' ),
                                          affected_id => session( 'user_id' ),
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    flash message => 'Deletion Flag Removed';
    return redirect '/my/account';
};

# User Profile Landing Page
get '/my/profile/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );
    my ( $user_hash ) = $user->get_user_hash_for_template();

    if ( ! defined $user_hash )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    my $is_public_hash      = $user->account->get_is_public_hash();
    my $enums               = Side7::Account->get_enum_values();
    my $date_visibilities   = Side7::DateVisibility::Manager->get_date_visibilities( query => [], sort_by => 'id' );
    my $countries           = Side7::User::Country::Manager->get_countries( query => [], sort_by => 'name' );
    my $public_visibilities = [ { name => 'Public', value => 1 }, { name => 'Private', value => 0 } ];

    template 'my/profile', {
                             user                => $user, 
                             enums               => $enums, 
                             date_visibilities   => $date_visibilities, 
                             countries           => $countries,
                             public_visibilities => $public_visibilities, 
                             is_public_hash      => $is_public_hash,
                           };
};

# User Profile Submission Page
post '/my/profile' => sub
{
    my $user = Side7::User::get_user_by_id( params->{'user_id'} );
    my $original_account = $user->account->clone();

    # Validate Input
    ## Create is_public hashref
    my $is_public_hash = {};
    my $is_public = '';
    foreach my $is_public_setting ( qw/ aim yahoo skype gtalk email state country / ) # TODO Cleaner way of listing?
    {
        $is_public_hash->{$is_public_setting} = params->{$is_public_setting.'_visibility'} // 1; # Defaults to Public
    }

    ## Ensure certain selectable values are defined.
    params->{'sex'}                 //= 'Unspecified';
    params->{'birthday_visibility'} //= 1;

    # Save Updated Items
    my $original_values = '';
    my $updated_values  = '';
    my $changed_fields  = '';
    foreach my $profile_item ( 
                                qw/ 
                                    other_aliases sex birthday_visibility country_id state
                                    webpage_name webpage_url blog_name blog_url
                                    aim yahoo gtalk skype biography
                                /
                             )
    {
        if (
            ( ! defined params->{$profile_item} && defined $original_account->$profile_item() )
            ||
            ( defined params->{$profile_item} && ! defined $original_account->$profile_item() )
            ||
            params->{$profile_item} ne $original_account->$profile_item()
        )
        {
            $user->account->$profile_item( params->{$profile_item} );
            $changed_fields  .= '&gt;' . $profile_item . '&lt;, ';
            $original_values .= $profile_item . ': &gt;' . $original_account->$profile_item() . '&lt;<br>';
            $updated_values  .= $profile_item . ': &gt;' . params->{$profile_item} . '&lt;<br>';
        }
    }

    my $original_is_public_hash = $user->account->get_is_public_hash();
    my $changed = 0;
    foreach my $is_public_key ( keys %$original_is_public_hash )
    {
        if (
            $original_is_public_hash->{$is_public_key} ne $is_public_hash->{$is_public_key}
        )
        {
            $changed = 1;
            $changed_fields  .= '&gt;' . $is_public_key . '_visibility&lt;, ';
            $original_values .= $is_public_key . '_visibility: &gt;' . $original_is_public_hash->{$is_public_key} . '&lt;<br>';
            $updated_values  .= $is_public_key . '_visibility: &gt;' . $is_public_hash->{$is_public_key} . '&lt;<br>';
        }
        if ( $changed == 1 )
        {
            $is_public = Side7::Account->serialize_is_public_hash( $is_public_hash );
            $user->account->is_public( $is_public );
        }
    }

    if ( $changed_fields ne '' )
    {
        $user->account->updated_at( DateTime->now() );
        $user->account->save();
    }

    # Audit Log
    my $audit_msg = 'User Profile Updated -- Successful<br>' .
                    'Profile for &gt;' . $user->username() . '&lt; ( User ID: ' . params->{'user_id'} . ' )' . 
                    ' updated by &gt;' . session( 'username' ) . '&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
    $audit_msg .= 'Fields changed:<br>' . $changed_fields;

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'User Preferences Updated',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => params->{'user_id'},
                                          original_value => $original_values,
                                          new_value      => $updated_values,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return
    my $is_public_hash      = $user->account->get_is_public_hash();
    my $enums               = Side7::Account->get_enum_values();
    my $date_visibilities   = Side7::DateVisibility::Manager->get_date_visibilities( query => [], sort_by => 'id' );
    my $countries           = Side7::User::Country::Manager->get_countries( query => [], sort_by => 'name' );
    my $public_visibilities = [ { name => 'Public', value => 1 }, { name => 'Private', value => 0 } ];

    flash message => 'Your Profile has been updated successfully!';
    template 'my/profile', {
                             user                => $user, 
                             enums               => $enums, 
                             date_visibilities   => $date_visibilities, 
                             countries           => $countries,
                             public_visibilities => $public_visibilities, 
                             is_public_hash      => $is_public_hash,
                           };
};

# User Gallery Landing Page
get '/my/gallery/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );
    my ( $user_hash ) = $user->get_user_hash_for_template();

    if ( ! defined $user_hash )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    template 'my/gallery', { user => $user_hash };
};

# User Kudos Landing Page
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

# User Preferences Settings Page
get '/my/preferences/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );
    my $user_preferences = Side7::User::Preference->new( user_id => session( 'user_id' ) );
    my $loaded = $user_preferences->load( speculative => 1 );

    if (
        $loaded == 0
        ||
        ! defined $user_preferences
        ||
        ref( $user_preferences ) ne 'Side7::User::Preference'
    )
    {
        flash error => 'Unable to retrieve your User Preferences from the system. Using default values.';
        $user_preferences = Side7::User::Preference->get_default_values( user_id => session( 'user_id' ) );
    }

    my $is_adult = 0;
    my $today = DateTime->today();
    if ( 
        ! defined $user->account->birthday()
        ||
        $user->account->birthday() eq '0000-00-00'
    )
    {
        # Legacy account with no birthday. Give no option to set Adult Content On.
        $is_adult = 0;
    } 
    else
    {
        my $duration = $today->subtract_datetime( $user->account->birthday() );
        if ( $duration->{'months'} >= $AGE_18_IN_MONTHS )
        {
            # Birthday is 18 years ago or more.
            $is_adult = 1;
        }
    }

    my $enums = Side7::User::Preference->get_enum_values();

    template 'my/preferences', { user_preferences => $user_preferences, enums => $enums, is_adult => $is_adult };
};

# User Preferences Update
post '/my/preferences' => sub
{

    # Retrieve the user for the changed account.  We do this to have the Username and ID for the affected user in the
    # event a Mod or Admin changes preferences.
    my $affected_user = Side7::User::get_user_by_id( params->{'user_id'} );

    # Validate that we got Preferences back. This ensures that we received something back by checking
    # With the 5 select fields that must have a non-boolean value.  All other preferences use a boolean
    # value, and so can be 0 or undef.  If any of the non-boolean values are undef, we'll grab the default
    # values for all of the prefs and just save that.
    my $orig_preferences = undef;
    if (
        ( ! defined params->{'default_comment_visibility'} || params->{'default_comment_visibility'} eq '' )
        ||
        ( ! defined params->{'default_comment_type'}       || params->{'default_comment_type'} eq '' )
        ||
        ( ! defined params->{'thumbnail_size'}             || params->{'thumbnail_size'} eq '' )
        ||
        ( ! defined params->{'content_display_type'}       || params->{'content_display_type'} eq '' )
        ||
        ( ! defined params->{'display_full_sized_images'}  || params->{'display_full_sized_images'} eq '' )
    )
    {
        $orig_preferences = Side7::User::Preference->get_default_values( user_id => session( 'user_id' ) );
    }

    # Grab the original prefs before we update them.
    my $values_updated  = 0;
    my $new_preferences = undef;

    my @fields = ( qw/ display_signature show_management_thumbs default_comment_visibility
                       default_comment_type allow_watching allow_favoriting allow_sharing
                       allow_email_through_forms allow_pms pms_notifications comment_notifications
                       show_online thumbnail_size content_display_type show_m_thumbs show_adult_content
                       display_full_sized_images filter_profanity / );

    my $field_changes = undef;
    my $old_values    = undef;
    my $new_values    = undef;

    $orig_preferences = Side7::User::Preference->new( user_id => session( 'user_id' ) );
    my $loaded = $orig_preferences->load( speculative => 1 );
    if (
        $loaded == 0
        ||
        ! defined $orig_preferences
        ||
        ref( $orig_preferences ) ne 'Side7::User::Preference'
    )
    {
        $values_updated = 1;
        $orig_preferences = Side7::User::Preference->get_default_values( user_id => session( 'user_id' ) );
        $new_preferences = $orig_preferences->clone();
        $field_changes = 'Created new User Preferences record with default values.';
        foreach my $key ( @fields )
        {
            $new_values .= "$key: &gt;" . ( $new_preferences->$key() || '' ) . '&lt;<br>';
        }
    }
    else
    {
        $new_preferences = $orig_preferences->clone();
        foreach my $key ( @fields )
        {
            if ( 
                ( ! defined $orig_preferences->$key() && defined params->{$key} )
                ||
                ( defined $orig_preferences->$key() && ! defined params->{$key} )
                ||
                $orig_preferences->$key() ne params->{$key}
            )
            {
                if ( ! defined params->{$key} || params->{$key} eq '' )
                {
                    params->{$key} = 0;
                }
                $values_updated = 1;
                $new_preferences->$key( params->{$key} );
                $field_changes .= "&gt;$key&lt;, ";
                $old_values    .= "$key: &gt;" . ( $orig_preferences->$key() || '' ) . '&lt;<br>';
                $new_values    .= "$key: &gt;" . ( $new_preferences->$key()  || '' ) . '&lt;<br>';
            }
        }
    }

    # Save Input
    if ( $values_updated == 1 )
    {
        $new_preferences->updated_at( DateTime->now() );
        $new_preferences->save();
    }

    # Record Audit Log
    my $audit_msg = 'User Preferences Updated -- Successful<br>' .
                    'Preferences for &gt;' . $affected_user->username() . '&lt; ( User ID: ' . params->{'user_id'} . ' )' . 
                    ' updated by &gt;' . session( 'username' ) . '&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
    $audit_msg .= 'Fields changed:<br>' . $field_changes;

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'User Preferences Updated',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => params->{'user_id'},
                                          original_value => $old_values,
                                          new_value      => $new_values,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return to template
    flash message => 'Your Preferences have been saved.';

    my $enums = Side7::User::Preference->get_enum_values();
    template 'my/preferences', { user_preferences => $new_preferences, enums => $enums };
};

# User Gallery Landing Page
get '/my/gallery/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );
    my ( $user_hash ) = $user->get_user_hash_for_template();

    if ( ! defined $user_hash )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    template 'my/gallery', { user => $user_hash };
};

# User Content Upload Page
get '/my/upload/?:upload_type?/?' => sub
{

    if ( ! defined params->{'upload_type'} )
    {
        flash error => 'Please ensure you have chosen which type of content you would like to upload.';
        return template 'my/gallery';
    }

    my $enums             = Side7::UserContent::get_enums_for_form( content_type => params->{'upload_type'} );
    my $categories        = Side7::UserContent::Category->get_categories_for_form( content_type => params->{'upload_type'} );
    my $ratings           = Side7::UserContent::Rating->get_ratings_for_form( content_type => params->{'upload_type'} );
    my $stages            = Side7::UserContent::Stage->get_stages_for_form( content_type => params->{'upload_type'} );
    my $qualifiers        = Side7::UserContent::RatingQualifier->get_rating_qualifiers_for_form( content_type => params->{'upload_type'} );

    template 'my/upload', { 
                            upload_type => params->{'upload_type'}, 
                            enums       => $enums,
                            categories  => $categories,
                            ratings     => $ratings,
                            qualifiers  => $qualifiers,
                            stages      => $stages,
                          };
};

# Upload Submission Processor
post '/my/upload' => sub
{
    my $params = params;

    my $return_to_form = sub
    {
        my $enums             = Side7::UserContent::get_enums_for_form( content_type => params->{'upload_type'} );
        my $categories        = Side7::UserContent::Category->get_categories_for_form( content_type => params->{'upload_type'} );
        my $ratings           = Side7::UserContent::Rating->get_ratings_for_form( content_type => params->{'upload_type'} );
        my $stages            = Side7::UserContent::Stage->get_stages_for_form( content_type => params->{'upload_type'} );
        my $qualifiers        = Side7::UserContent::RatingQualifier->get_rating_qualifiers_for_form( content_type => params->{'upload_type'} );
        return template 'my/upload', {
                            upload_type       => params->{'upload_type'}, 
                            overwrite_dupe    => params->{'overwrite_dupe'},
                            category_id       => params->{'category_id'},
                            rating_id         => params->{'rating_id'},
                            rating_qualifiers => params->{'rating_qualifiers'},
                            stage_id          => params->{'stage_id'},
                            title             => params->{'title'},
                            description       => params->{'description'},
                            copyright_year    => params->{'copyright_year'},
                            privacy           => params->{'privacy'},
                            enums             => $enums,
                            categories        => $categories,
                            ratings           => $ratings,
                            qualifiers        => $qualifiers,
                            stages            => $stages,
        };
    };

    # Validating params with rule file
    my $data = validator( $params, params->{'upload_type'} . '_upload_form.pl' );

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
        return $return_to_form->();
    }

    # Get User & Content Path
    my $user = Side7::User::get_user_by_username( session( 'username' ) );
    my $upload_dir = $user->get_content_directory();

    # If filename exists, and overwrite_dupe is not checked, bail with an error message.
    if
    (
        -f $upload_dir . params->{'filename'}
        &&
        ! defined params->{'overwrite_dupe'}
    )
    {
        my $err_message = 'You already have a file named <b>&apos;' . params->{'filename'} . '&apos;</b>.<br />';
        $err_message .= 'If you would like to replace that file with an updated copy, please check the <b>Overwrite file</b> box.';

        flash error => $err_message;
        return $return_to_form->();
    }

    # Upload the file
    my $file = request->upload( 'filename' );

    # Copy file to the User's directory
    $file->copy_to( $upload_dir . $file->filename() );

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_message = '';

    # Insert the content record into the database.
    # TODO: REFACTOR THIS CRAP.
    if ( lc( params->{'upload_type'} ) eq 'image' )
    {
        my $copyright_year = undef;
        if ( defined params->{'copyright_year'} )
        {
            $copyright_year = DateTime->today->year();
        }
        my $rating_qualifiers = undef;
        if ( defined params->{'rating_qualifiers'} )
        {
            if ( ref( params->{'rating_qualifiers'} ) eq 'ARRAY' )
            {
                $rating_qualifiers = join( '', @{ params->{'rating_qualifiers'} } );
            }
            else
            {
                $rating_qualifiers = params->{'rating_qualifiers'};
            }
        }

        my $file_stats = Side7::Utils::Image::get_image_stats( image => $upload_dir . $file->filename(), dimensions => 1 );
        if ( defined $file_stats->{'error'} )
        {
            $LOGGER->warn( 'ERROR GETTING IMAGE STATS: ' . $file_stats->{'error'} );
            flash error => 'Invalid file format has been uploaded as an image.';
            return $return_to_form->();
        }

        my $now = DateTime->now();

        my $image = Side7::UserContent::Image->new(
                                                    user_id           => $user->id(),
                                                    filename          => params->{'filename'},
                                                    filesize          => $file->size(),
                                                    dimensions        => $file_stats->{'dimensions'},
                                                    category_id       => params->{'category_id'},
                                                    rating_id         => params->{'rating_id'},
                                                    rating_qualifiers => $rating_qualifiers,
                                                    stage_id          => params->{'stage_id'},
                                                    title             => params->{'title'},
                                                    description       => params->{'description'},
                                                    copyright_year    => $copyright_year,
                                                    privacy           => params->{'privacy'},
                                                    created_at        => $now,
                                                    updated_at        => $now,
                                                  );

        $image->save();

        $audit_message = 'User ' . session( 'username' ) . ' (ID: ' . session( 'user_id' ) . ') uploaded new Content:<br />';
        $audit_message .= 'Content Type: image<br />';
        $audit_message .= 'Filename: &gt;' . params->{'filename'} . '&lt;<br />';
        $audit_message .= 'Filesize: &gt;' . $file->size() . '&lt;<br />';
        $audit_message .= 'Dimensions: &gt;' . $file_stats->{'dimensions'} . '&lt;<br />';
        $audit_message .= 'Category_id: &gt;' . params->{'category_id'} . '&lt;<br />';
        $audit_message .= 'Rating_id: &gt;' . params->{'rating_id'} . '&lt;<br />';
        $audit_message .= 'Rating_qualifiers: &gt;' . ( $rating_qualifiers // '' ) . '&lt;<br />';
        $audit_message .= 'Stage_id: &gt;' . params->{'stage_id'} . '&lt;<br />';
        $audit_message .= 'Title: &gt;' . params->{'title'} . '&lt;<br />';
        $audit_message .= 'Description: &gt;' . ( params->{'description'} // '' ) . '&lt;<br />';
        $audit_message .= 'Copyright_year: &gt;' . $copyright_year . '&lt;<br />';
        $audit_message .= 'Privacy: &gt;' . params->{'privacy'} . '&lt;<br />';
        $audit_message .= 'Created_at: &gt;' . $now . '&lt;<br />';
        $audit_message .= 'Updated_at: &gt;' . $now . '&lt;<br />';
    }
    elsif ( lc( params->{'upload_type'} ) eq 'music' )
    {
        # TODO: Create Music object.
    }
    elsif ( lc( params->{'upload_type'} ) eq 'literature' )
    {
        # TODO: Create Literature object.
    }
    else
    {
        my $err_message = 'Could not add your upload to the database as we could not determine what kind of content it was.' .
                          ' We have made note of this error and will look into it.';

        flash error => $err_message;
        return $return_to_form->();
    }

    my $audit_log = Side7::AuditLog->new(
                                          title       => 'New User Content Uploaded',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          timestamp   => DateTime->now(),
    );

    $audit_log->save();

    flash message => 'Hooray! Your file <b>' . $file->filename() . '</b> has been uploaded successfully.';

    template 'my/gallery';
};

# User Permissions Explanation Page ( Might be temporary )
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

# User Perks Landing Page ( Might be temporary )
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

package Side7::Admin;
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
use Side7::AuditLog::Manager;
use Side7::Login;
use Side7::News;
use Side7::News::Manager;
use Side7::User;
use Side7::Admin::Dashboard;
use Side7::Admin::Report;
use Side7::Utils::Pagination;

prefix '/admin';

# Ensure only those accounts with permission to reach the admin dashboard reach it.
hook 'before' => sub
{
    if ( request->path_info =~ m/^\/admin\// )
    {
        if ( ! session('username') )
        {
            $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
            flash error => 'You must be logged in, and a Moderator or Admin to view that page.';
            var rd_url => request->path_info;
            request->path_info( '/login' );
        }
        else
        {
            my $authorized = Side7::Login::user_authorization( 
                                                                session_username => session( 'username' ), 
                                                                username         => undef,
                                                                requires_mod     => 1,
                                                             );

            if ( $authorized != 1 )
            {
                my $error = 'User >' . session( 'username' ) . 
                                '< attempted but is not authorized to view >' . request->path_info . '<';
                $LOGGER->info( $error );

                my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
                my $audit_log = Side7::AuditLog->new(
                                                      title       => 'Unauthorized Admin Access Attempt',
                                                      description => $error,
                                                      ip_address  => request->address() . $remote_host,
                                                      timestamp   => DateTime->now(),
                );

                $audit_log->save();

                flash error => 'You are not authorized to view that page.';
                return redirect '/'; # Not an authorized page.
            }

            set layout => 'admin';
        }
    }
};

# Admin Main Dashboard Page
get '/' => sub
{
    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    my $data = Side7::Admin::Dashboard::show_main_dashboard();

    template 'admin/main', { main_menu => $menu_options, data => $data }, { layout => 'admin' };
};

# Admin User Dashboard Page
get qr{/users/?([A-Za-z0-9_]?)/?(\d*)/?} => sub
{
    my ( $initial, $page ) = splat;

    if ( ! defined $initial || $initial eq '' )
    {
        $initial = '0';
    }

    if ( ! defined $page || $page eq '' )
    {
        $page = 1;
    }

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    my $data = Side7::Admin::Dashboard::show_user_dashboard(
                                                            initial => $initial, 
                                                            page    => $page,
                                                           );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $data->{'user_count'}, page => $page } );

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user', { 
                                main_menu     => $menu_options, 
                                data          => $data, 
                                initial       => $initial, 
                                page          => $page,
                                pagination    => $pagination,
                                link_base_uri => '/admin/users',
                                permissions         => {
                                                        can_view_account_details => $admin_user->has_permission( 'can_view_account_details' ),
                                                        can_modify_user_account  => $admin_user->has_permission( 'can_modify_user_account' ),
                                                        can_disable_accounts     => $admin_user->has_permission( 'can_disable_accounts' ),
                                                       },
                           },
                           { layout => 'admin' };
};

# Admin User Dashboard Search Page
post '/users/search' => sub
{
    my $search_term = params->{'search_term'} // undef;
    my $status      = params->{'status'}      // undef;
    my $type        = params->{'type'}        // undef;
    my $role        = params->{'role'}        // undef;
    my $initial     = params->{'initial'}     // '0';
    my $page        = params->{'page'}        // '1';

    if
    (
        ( ! defined $search_term || $search_term eq '' )
        &&
        ( ! defined $status || $status eq '' )
        &&
        ( ! defined $type || $type eq '' )
        &&
        ( ! defined $role || $role eq '' )
    )
    {
        return redirect '/admin/users/' . $initial . '/' . $page;
    }

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    my $data = Side7::Admin::Dashboard::search_users(
                                                        search_term => $search_term,
                                                        status      => $status,
                                                        type        => $type,
                                                        role        => $role,
                                                        page        => $page,
                                                    );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $data->{'user_count'}, page => $page } );

    my $search_url_base = '/admin/users/search/' .
                          $search_term . '/' .
                          $status . '/' .
                          $type . '/' .
                          $role;

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user', { 
                                title         => 'Users',
                                query         => { 
                                                    search_term => $search_term,
                                                    status      => $status,
                                                    type        => $type,
                                                    role        => $role,
                                                 },
                                main_menu           => $menu_options, 
                                data                => $data, 
                                initial             => $initial, 
                                page                => $page,
                                pagination          => $pagination,
                                link_base_uri       => '/admin/users',
                                pagination_base_uri => $search_url_base,
                                permissions         => {
                                                        can_view_account_details => $admin_user->has_permission( 'can_view_account_details' ),
                                                        can_modify_user_account  => $admin_user->has_permission( 'can_modify_user_account' ),
                                                        can_disable_accounts     => $admin_user->has_permission( 'can_disable_accounts' ),
                                                       },
                           },
                           { layout => 'admin' };
};

# Admin User Dashboard Search Get Redirect for Pagination
get '/users/search/:search_term?/:status?/:type?/:role?/:intial/:page' => sub
{
    my $search_term = params->{'search_term'} // undef;
    my $status      = params->{'status'}      // undef;
    my $type        = params->{'type'}        // undef;
    my $role        = params->{'role'}        // undef;
    my $initial     = params->{'initial'}     // '0';
    my $page        = params->{'page'}        // '1';

    if (
        ( ! defined $search_term || $search_term eq '' )
        &&
        ( ! defined $status || $status eq '' )
        &&
        ( ! defined $type || $type eq '' )
        &&
        ( ! defined $role || $role eq '' )
    )
    {
        return redirect '/admin/users/' . $initial . '/' . $page;
    }

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    my $data = Side7::Admin::Dashboard::search_users(
                                                        search_term => $search_term,
                                                        status      => $status,
                                                        type        => $type,
                                                        role        => $role,
                                                        page        => $page,
                                                    );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $data->{'user_count'}, page => $page } );

    my $search_url_base = '/admin/users/search/' .
                          $search_term . '/' .
                          $status . '/' .
                          $type . '/' .
                          $role;

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user', { 
                                title         => 'Users',
                                query         => { 
                                                    search_term => $search_term,
                                                    status      => $status,
                                                    type        => $type,
                                                    role        => $role,
                                                 },
                                main_menu           => $menu_options, 
                                data                => $data, 
                                initial             => $initial, 
                                page                => $page,
                                pagination          => $pagination,
                                link_base_uri       => '/admin/users',
                                pagination_base_uri => $search_url_base,
                                permissions         => {
                                                        can_view_account_details => $admin_user->has_permission( 'can_view_account_details' ),
                                                        can_modify_user_account  => $admin_user->has_permission( 'can_modify_user_account' ),
                                                        can_disable_accounts     => $admin_user->has_permission( 'can_disable_accounts' ),
                                                       },
                           },
                           { layout => 'admin' };
};

# Admin User Dashboard Show User Details
get '/users/:username/show' => sub
{
    my $username = params->{'username'} // undef;

    if ( ! defined $username )
    {
        flash error => "Invalid username provided. Cannot display the User's details.";
        return redirect '/admin/users';
    }

    my $user = Side7::User::get_user_by_username( $username );

    my $user_hash = $user->get_user_hash_for_template( filter_profanity => 0 );

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user_details', {
                                        user => $user_hash,
                                        permissions => {
                                                        can_modify_user_account  => $admin_user->has_permission( 'can_modify_user_account' ),
                                                       },
                                   },
                                   { layout => 'admin_lightbox' };
};

# Admin User Dashboard Edit User Details
get '/users/:username/edit' => sub
{
    my $username = params->{'username'} // undef;

    if ( ! defined $username )
    {
        flash error => "Invalid username provided. Cannot edit the User's details.";
        return redirect '/admin/users';
    }

    my $sexes        = Side7::Admin::Dashboard::get_user_sexes_for_select();
    my $visibilities = Side7::Admin::Dashboard::get_birthday_visibilities_for_select();
    my $countries    = Side7::Admin::Dashboard::get_countries_for_select();

    my $user = Side7::User::get_user_by_username( $username );

    my $user_hash = $user->get_user_hash_for_template( 
                                                        filter_profanity => 0,
                                                        admin_dates      => 1,
                                                     );

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user_edit_form', {
                                        user        => $user_hash,
                                        data        => {
                                                        sexes                 => $sexes,
                                                        birthday_visibilities => $visibilities,
                                                        countries             => $countries,
                                                       },
                                        permissions => {
                                                        can_disable_accounts                => $admin_user->has_permission( 'can_disable_accounts' ),
                                                        can_refund_account_credits          => $admin_user->has_permission( 'can_refund_account_credits' ),
                                                        can_award_account_credits           => $admin_user->has_permission( 'can_award_account_credits' ),
                                                        can_suspend_accounts                => $admin_user->has_permission( 'can_suspend_accounts' ),
                                                        can_reinstate_accounts              => $admin_user->has_permission( 'can_reinstate_accounts' ),
                                                        can_reset_users_password            => $admin_user->has_permission( 'can_reset_users_password' ),
                                                        can_disable_accounts                => $admin_user->has_permission( 'can_disable_accounts' ),
                                                        can_reenable_accounts               => $admin_user->has_permission( 'can_reenable_accounts' ),
                                                        can_promote_forum_moderators        => $admin_user->has_permission( 'can_promote_forum_moderators' ),
                                                        can_demote_forum_moderators         => $admin_user->has_permission( 'can_demote_forum_moderators' ),
                                                        can_promote_site_moderators         => $admin_user->has_permission( 'can_promote_site_moderators' ),
                                                        can_demote_site_moderators          => $admin_user->has_permission( 'can_demote_site_moderators' ),
                                                        can_promote_site_admins             => $admin_user->has_permission( 'can_promote_site_admins' ),
                                                        can_demote_site_admins              => $admin_user->has_permission( 'can_demote_site_admins' ),
                                                        can_promote_owner                   => $admin_user->has_permission( 'can_promote_owner' ),
                                                        can_demote_owner                    => $admin_user->has_permission( 'can_demote_owner' ),
                                                        can_suspend_permissions             => $admin_user->has_permission( 'can_suspend_permissions' ),
                                                        can_reinstate_suspended_permissions => $admin_user->has_permission( 'can_reinstate_suspended_permissions' ),
                                                        can_revoke_permissions              => $admin_user->has_permission( 'can_revoke_permissions' ),
                                                        can_reinstate_revoked_permissions   => $admin_user->has_permission( 'can_reinstate_revoked_permissions' ),
                                                       },
                                   },
                                   { layout => 'admin_lightbox' };
};

# Admin User Dashboard Edit User Submission
post '/users/:username/edit' => sub
{
    my $params   = params;
    my $username = params->{'username'};

    my $return_to_form = sub
    {
        my $user = Side7::User::get_user_by_username( $username );

        my $user_hash = $user->get_user_hash_for_template( 
                                                            filter_profanity => 0,
                                                            admin_dates      => 1,
                                                         );

        my $sexes        = Side7::Admin::Dashboard::get_user_sexes_for_select();
        my $visibilities = Side7::Admin::Dashboard::get_birthday_visibilities_for_select();
        my $countries    = Side7::Admin::Dashboard::get_countries_for_select();

        my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

        return template 'admin/user_edit_form', {
                                            user        => $user_hash,
                                            data        => {
                                                            sexes                 => $sexes,
                                                            birthday_visibilities => $visibilities,
                                                            countries             => $countries,
                                                           },
                                            permissions => {
                                                            can_disable_accounts                => $admin_user->has_permission( 'can_disable_accounts' ),
                                                            can_refund_account_credits          => $admin_user->has_permission( 'can_refund_account_credits' ),
                                                            can_award_account_credits           => $admin_user->has_permission( 'can_award_account_credits' ),
                                                            can_suspend_accounts                => $admin_user->has_permission( 'can_suspend_accounts' ),
                                                            can_reinstate_accounts              => $admin_user->has_permission( 'can_reinstate_accounts' ),
                                                            can_reset_users_password            => $admin_user->has_permission( 'can_reset_users_password' ),
                                                            can_disable_accounts                => $admin_user->has_permission( 'can_disable_accounts' ),
                                                            can_reenable_accounts               => $admin_user->has_permission( 'can_reenable_accounts' ),
                                                            can_promote_forum_moderators        => $admin_user->has_permission( 'can_promote_forum_moderators' ),
                                                            can_demote_forum_moderators         => $admin_user->has_permission( 'can_demote_forum_moderators' ),
                                                            can_promote_site_moderators         => $admin_user->has_permission( 'can_promote_site_moderators' ),
                                                            can_demote_site_moderators          => $admin_user->has_permission( 'can_demote_site_moderators' ),
                                                            can_promote_site_admins             => $admin_user->has_permission( 'can_promote_site_admins' ),
                                                            can_demote_site_admins              => $admin_user->has_permission( 'can_demote_site_admins' ),
                                                            can_promote_owner                   => $admin_user->has_permission( 'can_promote_owner' ),
                                                            can_demote_owner                    => $admin_user->has_permission( 'can_demote_owner' ),
                                                            can_suspend_permissions             => $admin_user->has_permission( 'can_suspend_permissions' ),
                                                            can_reinstate_suspended_permissions => $admin_user->has_permission( 'can_reinstate_suspended_permissions' ),
                                                            can_revoke_permissions              => $admin_user->has_permission( 'can_revoke_permissions' ),
                                                            can_reinstate_revoked_permissions   => $admin_user->has_permission( 'can_reinstate_revoked_permissions' ),
                                                           },
                                       },
                                       { layout => 'admin_lightbox' };
    };

    # Validating params with rule file
    my $data = validator( $params, 'admin_user_edit_form.pl' );

    # Return to User Dashboard if errors.
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

        $return_to_form->();
    }

    # Save User.
    my $orig_user = Side7::User->new( id => params->{'user_id'} );
    my $loaded = $orig_user->load( speculative => 1, with_objects => [ 'account' ] );

    if ( $loaded == 0 || ref( $orig_user ) ne 'Side7::User' )
    {
        # Return to form.
        flash error => 'User >' . $username . '< could not be loaded from the database for editing.';
        $return_to_form->();
    }

    # User-specific
    my %user_changes = ();
    my $user_updated = 0;
    foreach my $field ( qw/ username email_address referred_by / )
    {
        if (
            ( defined params->{$field} && ! defined $orig_user->$field() )
            ||
            ( ! defined params->{$field} && defined $orig_user->$field() )
            ||
            ( 
                defined params->{$field} 
                &&
                defined $orig_user->$field()
                &&
                $orig_user->$field() ne params->{$field}
            )
        )
        {
            # Record change in hash.
            $user_changes{$field}{'old'} = ( $orig_user->$field() || '' );
            $user_changes{$field}{'new'} = ( params->{$field} || '' );

            # Make change.
            $orig_user->$field( ( params->{$field} || undef ) );
            $user_updated = 1;
        }
    }

    # Account-specific
    my %account_changes = ();
    my $account_updated = 0;
    foreach my $field ( qw/ first_name last_name biography sex birthday birthday_visibility webpage_name 
                            webpage_url blog_name blog_url aim yahoo gtalk skype state country_id 
                            subscription_expires_on delete_on / )
    {
        if (
            ( defined params->{$field} && ! defined $orig_user->account->$field() )
            ||
            ( ! defined params->{$field} && defined $orig_user->account->$field() )
            ||
            ( 
                defined params->{$field}
                &&
                defined $orig_user->account->$field()
                &&
                $orig_user->account->$field() ne params->{$field}
            )
        )
        {
            # Record change in hash.
            $account_changes{$field}{'old'} = ( $orig_user->account->$field() || '' );
            $account_changes{$field}{'new'} = ( params->{$field} || '' );

            # Make change.
            $orig_user->account->$field( ( params->{$field} || undef ) );
            $account_updated = 1;
        }
    }

    # Save changes
    if ( $account_updated == 1 || $user_updated == 1 )
    {
        # Update user updated_at
        $orig_user->updated_at( 'now' );

        if ( $account_updated == 1 )
        {
            # Update account updated_at
            $orig_user->account->updated_at( 'now' );
            $orig_user->account->save();
        }

        $orig_user->save();

        # Update Audit Log
        my $audit_msg = 'User Account Updated -- Successful<br>' .
                        'Account for &gt;' . $username . '&lt; ( User ID: ' . params->{'user_id'} . ' )' . 
                        ' updated by &gt;' . session( 'username' ) . '&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
        $audit_msg .= 'Fields changed:<br>';

        my $old_values = '';
        my $new_values = '';
        foreach my $key ( keys %user_changes )
        {
            $audit_msg .= "&gt;$key&lt;, "; 
            $old_values .= "$key: &gt;" . ( $user_changes{$key}{'old'} || '' ) . '&lt;<br>';
            $new_values .= "$key: &gt;" . ( $user_changes{$key}{'new'} || '' ) . '&lt;<br>';
        }
        foreach my $key ( keys %account_changes )
        {
            $audit_msg .= "&gt;$key&lt;, "; 
            $old_values .= "$key: &gt;" . ( $account_changes{$key}{'old'} || '' ) . '&lt;<br>';
            $new_values .= "$key: &gt;" . ( $account_changes{$key}{'new'} || '' ) . '&lt;<br>';
        }

        my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
        my $audit_log = Side7::AuditLog->new(
                                              title          => 'User Account Updated',
                                              description    => $audit_msg,
                                              ip_address     => request->address() . $remote_host,
                                              user_id        => session( 'user_id' ),
                                              affected_id    => params->{'user_id'},
                                              original_value => $old_values,
                                              new_value      => $new_values,
                                              timestamp      => DateTime->now(),
        );

        $audit_log->save();

    }

    flash message => 'User account for &gt;<b>' . $username . '</b>&lt; has been updated.';
    return redirect '/admin/users/' . $username . '/show';
};

# Admin Audit Logs View
get '/audit_logs/?:page?' => sub
{
    my $page = params->{'page'} // 1;
    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    if ( $admin_user->has_permission( 'can_view_audit_logs' ) == 0 )
    {
        flash error => 'You do not have permission to view Audit Logs.';
        return redirect '/admin';
    }

    my $log_count = Side7::AuditLog::Manager->get_audit_logs_count();

    my $audit_logs = Side7::AuditLog::Manager->get_audit_logs(
                                                                query    => [],
                                                                sort_by  => 'timestamp DESC',
                                                                page     => $page,
                                                                per_page => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
                                                             );
    
    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $log_count, page => $page } );

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    template 'admin/audit_logs', {
                                        data          => {
                                                            logs      => $audit_logs,
                                                            log_count => $log_count,
                                                         },
                                        main_menu     => $menu_options,
                                        link_base_uri => '/admin/audit_logs',
                                        pagination    => $pagination,
                                        permissions   => {
                                                         },
                                },
                                { layout => 'admin' };
};

# Admin Audit Logs Search
post '/audit_logs/search' => sub
{
    my $search_term = params->{'search_term'} // undef;
    my $page        = params->{'page'}        // '1';

    if
    (
        ( ! defined $search_term || $search_term eq '' )
    )
    {
        return redirect '/admin/audit_logs/' . $page;
    }

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    my $data = Side7::Admin::Dashboard::search_audit_logs(
                                                            search_term => $search_term,
                                                            page        => $page,
                                                         );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $data->{'log_count'}, page => $page } );

    my $search_url_base = '/admin/audit_logs/search/' . $search_term;

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/audit_logs', { 
                                query         => { 
                                                    search_term => $search_term,
                                                 },
                                main_menu           => $menu_options, 
                                data                => $data, 
                                page                => $page,
                                pagination          => $pagination,
                                link_base_uri       => '/admin/audit_logs/search',
                                pagination_base_uri => $search_url_base,
                                permissions         => {
                                                       },
                           },
                           { layout => 'admin' };
};

# Admin Audit Log Dashboard Search Get Redirect for Pagination
get '/audit_logs/search/:search_term?/?:page?' => sub
{
    my $search_term = params->{'search_term'} // undef;
    my $page        = params->{'page'}        // '1';

    if (
        ( ! defined $search_term || $search_term eq '' )
    )
    {
        return redirect '/admin/audit_logs/' . $page;
    }

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    my $data = Side7::Admin::Dashboard::search_audit_logs(
                                                            search_term => $search_term,
                                                            page        => $page,
                                                         );

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $data->{'log_count'}, page => $page } );

    my $search_url_base = '/admin/audit_logs/search/' .  $search_term;

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/audit_logs', { 
                                title         => 'Audit Logs',
                                query         => { 
                                                    search_term => $search_term,
                                                 },
                                main_menu           => $menu_options, 
                                data                => $data, 
                                page                => $page,
                                pagination          => $pagination,
                                link_base_uri       => '/admin/audit_logs',
                                pagination_base_uri => $search_url_base,
                                permissions         => {
                                                       },
                           },
                           { layout => 'admin' };
};

# Admin News Dashboard
get '/news/?:page?' => sub
{
    my $page = params->{'page'} // 1;
    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    my $news_count = Side7::News::Manager->get_news_count();

    my $results = Side7::News::Manager->get_news(
                                                       query        => [],
                                                       with_objects => [ 'user' ],
                                                       sort_by      => 'created_at DESC',
                                                       page         => $page,
                                                       per_page     => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
                                                   );

    my $news = ();
    foreach my $result ( @$results )
    {
        my $news_hash = {};
        foreach my $key ( qw/ id title blurb body link_to_article priority created_at updated_at / )
        {
            if ( $key eq 'body' )
            {
                $news_hash->{'body'} = Side7::Utils::Text::sanitize_text_for_html( $result->body() );
            }
            else
            {
                $news_hash->{$key} = $result->$key();
            }
        }
        $news_hash->{'user'} = $result->user->get_user_hash_for_template();

        push ( @$news, $news_hash );
    }
    
    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $news_count, page => $page } );

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );
    my $priorities = Side7::News->get_priority_names();

    template 'admin/news', {
                                        data          => {
                                                            news       => $news,
                                                            news_count => $news_count,
                                                            priorities => $priorities,
                                                         },
                                        main_menu     => $menu_options,
                                        link_base_uri => '/admin/news',
                                        pagination    => $pagination,
                                        permissions   => {
                                                            can_post_site_news => $admin_user->has_permission( 'can_post_site_news' ),
                                                         },
                                },
                                { layout => 'admin' };
};

# Admin News Dashboard Show Article Details
get '/news/:news_id/show' => sub
{
    my $news_id = params->{'news_id'} // undef;

    if ( ! defined $news_id )
    {
        flash error => "Invalid News ID provided. Cannot display the News item's details.";
        return redirect '/admin/news';
    }

    my $news = Side7::News->new( id => $news_id );
    my $loaded = $news->load( speculative => 1, with => [ 'user' ] );

    if ( $loaded == 0 || ref( $news ) ne 'Side7::News' )
    {
        flash error => 'Invalid News ID provided. Cannot display the News item\'s details.';
        return redirect '/admin/news';
    }

    my $news_hash = $news->get_news_hash_for_template();
    my $priorities = Side7::News->get_priority_names();

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/news_details', {
                                        news        => $news_hash,
                                        data        => {
                                                        priorities => $priorities,
                                                       },
                                        permissions => {
                                                        can_post_site_news  => $admin_user->has_permission( 'can_post_site_news' ),
                                                       },
                                   },
                                   { layout => 'admin_lightbox' };
};

# Admin News Dashboard Edit Article Details
get '/news/:news_id/edit' => sub
{
    my $news_id = params->{'news_id'} // undef;

    if ( ! defined $news_id )
    {
        flash error => "Invalid News ID provided. Cannot edit the News Item's details.";
        return redirect '/admin/news';
    }

    my $news = Side7::News->new( id => $news_id );
    my $loaded = $news->load( speculative => 1, with => [ 'user' ] );

    if ( $loaded == 0 || ref( $news ) ne 'Side7::News' )
    {
        flash error => 'Invalid News ID provided. Cannot display the News item\'s details.';
        return redirect '/admin/news';
    }

    my $news_hash = $news->get_news_hash_for_template( format_dates => 0 );
    my $priorities = Side7::News->get_priority_names();

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/news_edit_form', {
                                        news        => $news_hash,
                                        data        => {
                                                        priorities => $priorities,
                                                       },
                                        permissions => {
                                                        can_post_site_news  => $admin_user->has_permission( 'can_post_site_news' ),
                                                       },
                                   },
                                   { layout => 'admin_lightbox' };
};

# Admin News Dashboard Edit News Submission
post '/news/:news_id/edit' => sub
{
    my $params  = params;
    my $news_id = params->{'news_id'} // undef;

    my $return_to_form = sub
    {
        my $news = Side7::News->new( id => $news_id );
        my $loaded = $news->load( speculative => 1, with => [ 'user' ] );

        if ( $loaded == 0 || ref( $news ) ne 'Side7::News' )
        {
            flash error => 'Invalid News ID provided. Cannot display the News item\'s details.';
            return redirect '/admin/news';
        }

        my $news_hash = $news->get_news_hash_for_template( format_dates => 0 );
        my $priorities = Side7::News->get_priority_names();

        my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

        return template 'admin/news_edit_form', {
                                                    news_id     => $news_id,
                                                    news        => $news_hash,
                                                    data        => {
                                                                    priorities => $priorities,
                                                                   },
                                                    permissions => {
                                                                    can_post_site_news  => $admin_user->has_permission( 'can_post_site_news' ),
                                                                   },
                                               },
                                               { layout => 'admin_lightbox' };
    };

    # Validating params with rule file
    my $data = validator( $params, 'admin_news_edit_form.pl' );

    # Return to User Dashboard if errors.
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

        $return_to_form->();
    }

    # Save News.
    my $orig_news = Side7::News->new( id => params->{'news_id'} );
    my $loaded = $orig_news->load( speculative => 1, with_objects => [ 'user' ] );

    if ( $loaded == 0 || ref( $orig_news ) ne 'Side7::News' )
    {
        # Return to form.
        flash error => 'News Item for ID >' . $news_id . '< could not be loaded from the database for editing.';
        $return_to_form->();
    }

    # News-specific
    my %news_changes = ();
    my $news_updated = 0;
    foreach my $field ( qw/ title blurb body link_to_article priority is_static not_static_after user_id / )
    {
        if (
            ( defined params->{$field} && ! defined $orig_news->$field() )
            ||
            ( ! defined params->{$field} && defined $orig_news->$field() )
            ||
            ( 
                defined params->{$field} 
                &&
                defined $orig_news->$field()
                &&
                $orig_news->$field() ne params->{$field}
            )
        )
        {
            # Record change in hash.
            $news_changes{$field}{'old'} = ( $orig_news->$field() || '' );
            $news_changes{$field}{'new'} = ( params->{$field} || '' );

            # Make change.
            $orig_news->$field( ( params->{$field} || undef ) );
            $news_updated = 1;
        }
    }

    # Save changes
    if ( $news_updated == 1 )
    {
        # Update user updated_at
        $orig_news->updated_at( 'now' );

        $orig_news->save();

        # Update Audit Log
        my $audit_msg = 'News Item Updated -- Successful<br>' .
                        'Item &gt;' . $orig_news->title() . '&lt; ( News ID: ' . $news_id . ' )' . 
                        ' updated by &gt;' . session( 'username' ) . '&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
        $audit_msg .= 'Fields changed:<br>';

        my $old_values = '';
        my $new_values = '';
        foreach my $key ( keys %news_changes )
        {
            $audit_msg .= "&gt;$key&lt;, "; 
            $old_values .= "$key: &gt;" . ( $news_changes{$key}{'old'} || '' ) . '&lt;<br>';
            $new_values .= "$key: &gt;" . ( $news_changes{$key}{'new'} || '' ) . '&lt;<br>';
        }

        my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
        my $audit_log = Side7::AuditLog->new(
                                              title          => 'News Item Updated',
                                              description    => $audit_msg,
                                              ip_address     => request->address() . $remote_host,
                                              user_id        => session( 'user_id' ),
                                              affected_id    => params->{'user_id'},
                                              original_value => $old_values,
                                              new_value      => $new_values,
                                              timestamp      => DateTime->now(),
        );

        $audit_log->save();

    }

    flash message => 'News Item &gt;<b>' . $orig_news->title() . '</b>&lt; has been updated.';
    return redirect '/admin/news/' . $news_id . '/show';
};

true;
