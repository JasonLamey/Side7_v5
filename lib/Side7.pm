package Side7;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::FlashMessage;
use Dancer::Plugin::ValidateTiny;
use Dancer::Plugin::Email;
use Dancer::Plugin::DirectoryView;
use Dancer::Plugin::TimeRequests;
#use Dancer::Plugin::NYTProf;

use DateTime;
use Data::Dumper;
use Const::Fast;
use List::MoreUtils qw{none};
use Try::Tiny;

use Side7::Globals;
use Side7::AuditLog;
use Side7::Search;
use Side7::Login;
use Side7::News::Manager;
use Side7::User;
use Side7::User::ChangePassword;
use Side7::User::AccountDelete;
use Side7::User::Avatar::SystemAvatar::Manager;
use Side7::DateVisibility::Manager;
use Side7::Account;
use Side7::UserContent::Image;
use Side7::UserContent::Music;
use Side7::UserContent::RatingQualifier;
use Side7::UserContent::AlbumImageMap;
use Side7::UserContent::AlbumMusicMap;
use Side7::UserContent::Comment::Manager;
use Side7::Utils::Crypt;
use Side7::Utils::Pagination;
use Side7::Utils::Image;
use Side7::Utils::Music;
use Side7::FAQCategory;
use Side7::FAQCategory::Manager;
use Side7::FAQEntry;
use Side7::PrivateMessage;
use Side7::PrivateMessage::Manager;

use version; our $VERSION = qv( '0.1.44' );

# Dancer Settings
set charset => 'UTF-8';

const my $AGE_18_IN_MONTHS => 216;

hook 'before_template_render' => sub
{
    my $tokens = shift;

    $tokens->{'css_url'}    = request->base . 'css/style.css';
    $tokens->{'login_url'}  = uri_for( '/login'  );
    $tokens->{'logout_url'} = uri_for( '/logout' );
    $tokens->{'signup_url'} = uri_for( '/signup' );
    $tokens->{'user_home_url'} = uri_for( '/my/home' );
    $tokens->{'site_version'} = $CONFIG->{'general'}->{'version'};

    if ( defined session( 'logged_in' ) )
    {
        my $visitor =
            Side7::User->new( id => session( 'user_id' ) )->load( speculative => 1, with => [ 'account' ] );
        $tokens->{'header_avatar'} = $visitor->get_avatar( { size => 'tiny' } );
    }
};

hook 'before' => sub
{
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

    my $aotd = Side7::User::AOTD->new( date => DateTime->today() );
    my $loaded = $aotd->load( speculative => 1, with_objects => [ 'user', 'user.account' ] );

    my $aotd_content = [];
    if ( $loaded != 0 )
    {
        $aotd_content = Side7::UserContent->get_random_content_for_user(
                                                                            user    => $aotd->user,
                                                                            limit   => 10,
                                                                            size    => 'small',
                                                                            session => session,
                                                                       );
    }

    my $recents = Side7::UserContent->get_recent_uploads( limit => 20, size => 'small', session => session );

    template 'index', {
                        data => {
                                    news         => $results,
                                    sticky_news  => $stickies,
                                    aotd         => $aotd->user,
                                    aotd_content => $aotd_content,
                                    recents      => $recents,
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
                                    title         => 'News',
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
        flash error => 'Invalid News ID - Cannot retrieve news article.';
        return redirect '/news';
    }

    my $news_item = Side7::News->get_news_article( news_id => $news_id );

    if ( ! defined $news_item )
    {
        flash error => 'Invalid News ID - Article could not be found.';
        return redirect '/news';
    }

    template 'news/article', {
                                 title => 'News: ' . $news_item->title,
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

get '/un_search' => sub {
    set serializer => 'JSON';
    my $users = Side7::User::Manager->get_users( query => [
                                                            or => [
                                                                    't1.username'   => { like => '%' . params->{'term'} . '%' },
                                                                    't2.first_name' => { like => '%' . params->{'term'} . '%' },
                                                                    't2.last_name'  => { like => '%' . params->{'term'} . '%' },
                                                                  ],
                                                          ],
                                                 sort_by => 'username asc',
                                                 with_objects => [ 'account' ],
    );

    my @found = map { { label => $_->account->full_name . ' (' .$_->username . ')', value => $_->username } } @$users;

    return \@found;
};

###################################
### Special Error Page routes   ###
###################################

# Could Not Find User Content
get '/user_content_not_found' => sub
{
    status 'not_found';
    template 'errors/user_content_not_found.tt', {
                                                    path         => params->{'path'},
                                                    content_type => params->{'content_type'},
                                                 };
};

# Could Not Find User
get '/user_not_found' => sub
{
    status 'not_found';
    template 'errors/user_not_found.tt', {
                                            path     => params->{'path'},
                                            username => params->{'username'},
                                         };
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
            uri_base => request->uri_base,
        }
    );

    template 'login/login_form', { title => 'Login', rd_url => $rd_url };
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
                                                user_id     => $user->id,
                                                affected_id => $user->id,
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
    return template 'login/login_form', { title => 'Login', username => params->{'username'}, rd_url => params->{'rd_url'} };
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
    template 'user/signup_form', { title => 'Sign Up!' };
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
            title         => 'Sign Up!',
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
            title         => 'Sign Up!',
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

    template 'user/confirmed_user', { title => 'Confirm Your Account' };
};

# New User Post-redirect to Get

post '/confirm_user' => sub
{
    return redirect '/confirm_user/' . params->{'confirmation_code'};
};

# Forgot password view
get '/forgot_password' => sub
{
    template 'login/forgot_password_form.tt', { title => 'Forgot My Password' };
};

# Forgot password initial action
post '/forgot_password' => sub
{
    my $username = params->{'username'};

    if ( ! defined $username || $username =~ m/^\s+$/ )
    {
        flash error => 'You must enter a username in order to reset your password.';
        return template 'login/forgot_password_form.tt', { title => 'Forgot My Password' };
    }

    my $user = Side7::User->new( username => $username );
    my $loaded = $user->load( speculative => 1 );
    if ( $loaded == 0 || ref( $user ) ne 'Side7::User' )
    {
        flash error => '<strong>' . $username . '</strong> is an invalid username. Could not retrieve any account under that name.';
        return template 'login/forgot_password_form.tt', { title => 'Forgot My Password' };
    }

    my $reset_code = Side7::Utils::Crypt::sha1_hex_encode( $username . time() );
    my $reset_link = uri_for( "/reset_password/$reset_code" );

    my $new_password = Side7::User::ChangePassword->generate_random_password( 10 ); # Random password should be 10 chars long.

    # Record change to be made in a temp record
    my $password_change = Side7::User::ChangePassword->new(
                                                            user_id           => $user->id,
                                                            confirmation_code => $reset_code,
                                                            new_password      => $new_password,
                                                            is_a_reset        => 1,
                                                            created_at        => DateTime->now,
                                                            updated_at        => DateTime->now,
                                                          );

    $password_change->save();

    my $email_body = template 'email/reset_password_confirmation', {
        user       => $user,
        reset_link => $reset_link,
    }, { layout => 'email' };

    email {
        from    => 'system@side7.com',
        to      => $user->email_address,
        subject => 'Password Reset Confirmation',
        body    => $email_body,
    };

    template 'login/forgot_password_confirm.tt', { title => 'Confirm Password Reset', username => $username };
};

# Reset Password Action
get '/reset_password/?:reset_code?' => sub
{
    if ( ! defined params->{'reset_code'} )
    {
        flash error => 'You need to enter your password reset confirmation code.';
        return template 'login/reset_password_confirmation_form';
    }

    my $results = Side7::User::ChangePassword->reset_password( params->{'reset_code'} );

    if ( $results->{'success'} == 0 )
    {
        flash error => $results->{'error'};
        return template 'login/reset_password_confirmation_form', { reset_code => params->{'reset_code'} };
    }

    my $email_body = template 'email/reset_password_complete', {
        user         => $results->{'user'},
        new_password => $results->{'new_password'},
    }, { layout => 'email' };

    email {
        from    => 'system@side7.com',
        to      => $results->{'user'}->email_address,
        subject => 'Password Reset Complete',
        body    => $email_body,
    };

    my $audit_message = 'Password Reset confirmation - <b>Successful</b> - ';
    $audit_message   .= 'Confirmation Code: &gt;<b>' . params->{'reset_code'} . '</b>&lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Reset Password Confirmation',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          affected_id => $results->{'user'}->id,
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    template 'login/reset_password_complete', { title => 'Password Reset Complete' };
};

# Reset Password Post-redirect to Get
post '/reset_password' => sub
{
    return redirect '/reset_password/' . params->{'reset_code'};
};

# Forgot username view
get '/forgot_username' => sub
{
    template 'login/forgot_username_form.tt', { title => 'Forgot My Username' };
};

# Forgot password action
post '/forgot_username' => sub
{
    my $email_address = params->{'email_address'} // undef;

    if ( ! defined $email_address || $email_address =~ m/^\s*$/ )
    {
        flash error => 'You must enter an e-mail address in order to reset your password.';
        return template 'login/forgot_username_form.tt', { title => 'Forgot My Username' };
    }

    my $user = Side7::User->new( email_address => $email_address );
    my $loaded = $user->load( speculative => 1 );
    if ( $loaded == 0 || ref( $user ) ne 'Side7::User' )
    {
        $LOGGER->info( 'Invalid e-mail address entered for forgot_username: >' . $email_address . '<' );
        return template 'login/forgot_username_complete.tt', { title => 'Forgot My Username' };
    }

    $LOGGER->info( 'Sending forgot_username e-mail to User >' . $user->username . '< at >' . $email_address . '<' );

    my $email_body = template 'email/forgot_username', {
        user => $user,
    }, { layout => 'email' };

    email {
        from    => 'system@side7.com',
        to      => $user->email_address,
        subject => 'Forgotten Username',
        body    => $email_body,
    };

    my $audit_message = 'Forgot Username Request - <b>Successful</b> - ';
    $audit_message   .= 'Fulfilled a Forgot Username Request for &gt;<b>' . $email_address . '</b>&lt; which';
    $audit_message   .= 'belongs to &gt;' . $user->username . '&lt; (User ID: ' . $user->id . ' )';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title       => 'Forgot Username Request',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          affected_id => $user->id,
                                          timestamp   => DateTime->now(),
    );
    $audit_log->save();

    template 'login/forgot_username_complete', { title => 'Username Retrieval Complete' };
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

    my ( $search_results, $search_error ) = $search->get_results(
                                                                    look_for         => params->{'look_for'},
                                                                    page             => $page,
                                                                    filter_profanity => vars->{'filter_profanity'},
                                                                );

    template 'search/search_form', {
                                    title        => 'Search',
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

        return template 'faq', { title => 'FAQ', category => $category, entries => \@entries };
    }
    else
    {
        # FAQ General Page
        my $categories = Side7::FAQCategory::Manager->get_faq_categories( sort_by => 'priority ASC' );

        return template 'faq', { title => 'FAQ', categories => $categories };
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
                                        title         => 'User Directory: ' . uc( $initial ),
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
    my ( $user, $filtered_data ) = Side7::User::show_profile(
                                                                username => params->{'username'},
                                                                filter_profanity => vars->{'filter_profanity'},
                                                            );

    my $friend_link = undef;
    if ( defined session( 'logged_in' ) && defined $user && ref( $user ) eq 'Side7::User' )
    {
        my $visitor = Side7::User::get_user_by_id( session( 'user_id' ) );
        if ( defined $visitor && ref( $visitor ) eq 'Side7::User' )
        {
            my $is_linked = $visitor->is_friend_linked( user_id => $user->id );

            if ( $is_linked == 1 )
            {
                $friend_link = 'friend';
            }
            elsif ( $is_linked == 2 )
            {
                $friend_link = 'pending';
            }
            elsif ( $is_linked == 3 )
            {
                $friend_link = 'pending_received';
            }
            else
            {
                $friend_link = 'friend_link';
            }
        }
    }

    if ( defined $user && ref( $user ) eq 'Side7::User' )
    {
        template 'user/show_user_profile', {
                                                title         => $user->account->full_name . ' (' . $user->username . ')',
                                                user          => $user,
                                                filtered_data => $filtered_data,
                                                friend_link   => $friend_link,
                                           };
    }
    else
    {
        return forward '/user_not_found', { path => request->path, username => params->{'username'} };
    }
};

# Old v4 style URL redirect
get '/profile.cgim' => sub
{
    redirect '/user/' . params->{'member'};
};


# User Gallery page.
get '/gallery/:username/?' => sub
{
    redirect '/user/' . params->{'username'} . '/gallery';
};

# v4 style User Gallery link.
get '/gallery.cgim' => sub
{
    redirect '/user/' . params->{'member'} . '/gallery';
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

    template 'user/show_gallery', { title => 'Gallery For ' . $user->account->full_name, user => $user, gallery => $gallery };
};

# S7v4 Image Path Redirect
get '/image.cgim' => sub
{
    redirect '/image/' . params->{'image_id'};
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

    if ( defined $image_hash && scalar( keys %{ $image_hash } ) > 0 )
    {
        template 'user_content/image_details', {
                                                title         => '"' . $image_hash->{'content'}->title . '" by ' .
                                                                 $image_hash->{'content'}->user->account->full_name,
                                                user_content  => $image_hash,
                                                owner_ratings => $CONFIG->{'owner_ratings'},
                                               };
    }
    else
    {
        return forward '/user_content_not_found', { path => request->path, content_type => 'image' };
    }
};

# Music display page.
get '/music/:music_id/?' => sub
{
    my $music_hash = Side7::UserContent::Music->show_music(
                                                            music_id => params->{'music_id'},
                                                            request  => request,
                                                            session  => session,
    );

    if ( defined $music_hash && scalar( keys %{ $music_hash } ) > 0 )
    {
        # Create temp path to the file
        my $user_content_path = $music_hash->{'content'}->user->get_content_directory( 'music' );
        my $user_filepath = $user_content_path . $music_hash->{'content'}->filename;
        my $temp_link = Side7::Utils::Crypt::md5_hex_encode( session( 'id' ) . DateTime->now() ) .
                        '.' . $music_hash->{'content'}->encoding;
        my $temp_path = '/data/cached_files/audio/' . $temp_link;

        my $linked = 0;
        try
        {
            $linked = symlink( $user_filepath, $temp_path );
        }
        catch
        {
            $LOGGER->error( 'Could not symlink User music file >' . $user_filepath . '< to temp path >' . $temp_path . '<: >' . $_ . '<' );
        };

        if ( $linked == 1 )
        {
            ( $music_hash->{'filtered_content'}->{'filepath'} = $temp_path ) =~ s/^\/data//;
        }
        else
        {
            flash error => 'Error: Could not retrieve audio file.';
        }
        template 'user_content/music_details', {
                                                title         => '"' . $music_hash->{'content'}->title . '" by ' .
                                                                 $music_hash->{'content'}->user->account->full_name,
                                                user_content  => $music_hash,
                                                owner_ratings => $CONFIG->{'owner_ratings'},
                                               };
    }
    else
    {
        return forward '/user_content_not_found', { path => request->path, content_type => 'music' };
    }
};

# Create User Content Comment & Thread
get qr{/([A-Za-z0-9]+)/([0-9]+)/comment/?} => sub
{
    my ( $content_type, $content_id ) = splat;

    # USER MUST BE LOGGED IN TO COMMENT
    if ( ! defined session('logged_in') )
    {
        $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
        flash error => 'You must be logged in to leave a comment.';
        return forward '/login', { rd_url => "/$content_type/$content_id/comment" };
    }

    if
    (
        lc( $content_type ) ne 'image'
        &&
        lc( $content_type ) ne 'music'
        &&
        lc( $content_type ) ne 'literature'
        &&
        lc( $content_type ) ne 'video'
    )
    {
        $LOGGER->warn( 'Invalid content_type provided: >' . $content_type . '<' );
        flash error => 'Could not find comments for the content type you were looking for.';
    }

    if ( ! defined $content_id )
    {
        $LOGGER->warn( 'Invalid content_id provided: >' . $content_id . '<' );
        flash error => 'Could not find comments for the content you were looking for.';
    }

    my $content = undef;
    if ( lc( $content_type ) eq 'video' )
    {
        #$content = Side7::UserContent::Video->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
        #$content = Side7::UserContent::Literature->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
        $content = Side7::UserContent::Music->new( id => $content_id );
    }
    else
    {
        $content = Side7::UserContent::Image->new( id => $content_id );
    }

    my $loaded = $content->load( speculative => 1, with_objects => [ 'user' ] );
    if ( $loaded == 0 )
    {
        return '<strong>Could not access the content you were trying to comment upon.</strong>';
    }

    my $enums = Side7::UserContent::Comment->get_enum_values();

    template 'user_content/comment_compose.tt', {
                                                    content => $content,
                                                    enums   => $enums,
                                                }, { layout => 'main_lightbox' };
};

# Reply to Comment
get qr{/([A-Za-z0-9]+)/([0-9]+)/comment/([0-9]+)/reply/?} => sub
{
    my ( $content_type, $content_id, $comment_id ) = splat;

    # USER MUST BE LOGGED IN TO COMMENT
    if ( ! defined session('logged_in') )
    {
        $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
        flash error => 'You must be logged in to reply to a comment.';
        return forward '/login', { rd_url => "/$content_type/$content_id/comment/$comment_id/reply" };
    }

    if
    (
        lc( $content_type ) ne 'image'
        &&
        lc( $content_type ) ne 'music'
        &&
        lc( $content_type ) ne 'literature'
        &&
        lc( $content_type ) ne 'video'
    )
    {
        $LOGGER->warn( 'Invalid content_type provided: >' . $content_type . '<' );
        flash error => 'Could not find comments for the content type you were looking for.';
    }

    if ( ! defined $content_id )
    {
        $LOGGER->warn( 'Invalid content_id provided: >' . $content_id . '<' );
        flash error => 'Could not find comments for the content you were looking for.';
    }

    if ( ! defined $comment_id )
    {
        $LOGGER->warn( 'Invalid comment_id provided: >' . $comment_id . '<' );
        flash error => 'Could not find comments for the content you were looking for.';
    }

    my $content = undef;
    if ( lc( $content_type ) eq 'video' )
    {
        #$content = Side7::UserContent::Video->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
        #$content = Side7::UserContent::Literature->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
        $content = Side7::UserContent::Music->new( id => $content_id );
    }
    else
    {
        $content = Side7::UserContent::Image->new( id => $content_id );
    }

    my $loaded = $content->load( speculative => 1, with_objects => [ 'user' ] );
    if ( $loaded == 0 )
    {
        return '<strong>Could not access the content you were trying to comment upon.</strong>';
    }

    my $replying_to = Side7::UserContent::Comment->new( id => $comment_id );
    $loaded = $replying_to->load( speculative => 1, with_objects => [ 'user' ] );
    if ( $loaded == 0 )
    {
        return '<strong>Could not access the comment you were trying to reply to.</strong>';
    }

    my $enums = Side7::UserContent::Comment->get_enum_values();

    template 'user_content/comment_compose.tt', {
                                                    content => $content,
                                                    comment => $replying_to,
                                                    enums   => $enums,
                                                }, { layout => 'main_lightbox' };
};

# Submit comment Action
post qr{/user_content/comment/save/?} => sub
{
    my $content_type      = params->{'content_type'}      // undef;
    my $content_id        = params->{'content_id'}        // undef;
    my $comment_thread_id = params->{'comment_thread_id'} // undef;
    my $comment           = params->{'comment'}           // undef;
    my $replied_to        = params->{'replied_to'}        // undef;
    my $comment_type      = params->{'comment_type'}      // 'Commentary';
    my $private           = params->{'private'}           // 0;
    my $award             = params->{'award'}             // 'None';

    # USER MUST BE LOGGED IN TO COMMENT
    if ( ! defined session('logged_in') )
    {
        $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
        flash error => 'You must be logged in to leave a comment.';
        return forward '/login', { rd_url => '/user_content/comment/save' };
    }

    if ( ! defined $content_type )
    {
        flash error => 'An error has occurred.  Could not save the comment.';
        $LOGGER->warn( 'Could not save comment on User Content: invalid or missing content_type value.' );
        return '<p>Comment not saved.</p>';
    }

    if
    (
        lc( $content_type ) ne 'image'
        &&
        lc( $content_type ) ne 'literature'
        &&
        lc( $content_type ) ne 'music'
        &&
        lc( $content_type ) ne 'video'
    )
    {
        flash error => 'Invalid content type. Could not save comment.';
        $LOGGER->warn( 'Received invalid content_type of >' . $content_type . '< when saving comment.' );
        return '<p>Comment not saved.</p>';
    }

    if ( $content_id !~ m/^\d+$/ )
    {
        flash error => 'Invalid content ID. Could not save comment.';
        $LOGGER->warn( 'Received invalid comment_id of >' . $content_id . '< when saving comment.' );
        return '<p>Comment not saved.</p>';
    }

    if ( ! defined $comment || $comment eq '' )
    {
        flash error => 'Cannot save a comment with no content.';
        return '<p>Comment not saved.</p>';
    }

    # Ensure the comment_thread_id is valid
    if ( defined $comment_thread_id && $comment_thread_id =~ m/^\d+$/ )
    {
        my $thread_exists = Side7::UserContent::CommentThread::Manager->get_comment_threads_count(
                                                                                                    query => [
                                                                                                                id            => $comment_thread_id,
                                                                                                                content_type  => $content_type,
                                                                                                                content_id    => $content_id,
                                                                                                                thread_status => 'Open',
                                                                                                             ],
        );
        if ( ! defined $thread_exists )
        {
            flash error => 'Invalid Comment Thread. Could not save comment.';
            $LOGGER->warn( 'Received comment_thread_id >' . $comment_thread_id . '< of an invalid comment thread when saving comment.' );
            return '<p>Comment not saved.</p>';
        }
    }

    my $content = undef;
    if ( lc( $content_type ) eq 'video' )
    {
        #$content = Side7::UserContent::Video->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
        #$content = Side7::UserContent::Literature->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
        $content = Side7::UserContent::Music->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'image' )
    {
        $content = Side7::UserContent::Image->new( id => $content_id );
    }
    else
    {
        flash error => 'Invalid Content Type. Could not save comment.';
        $LOGGER->warn( 'Received invalid content_id >' . $content_id . '< for a(n) ' . $content_type . ' when saving comment.' );
        return '<p>Comment not saved.</p>';
    }

    my $loaded = $content->load( speculative => 0, with_objects => [ 'user' ] );
    if ( $loaded == 0 )
    {
        flash error => 'Invalid Content ID. Could not save comment.';
        $LOGGER->warn( 'Received invalid content_id >' . $content_id . '< for a(n) ' . $content_type . ' when saving comment.' );
        return '<p>Comment not saved.</p>';
    }

    # Save Comment
    if
    (
        ! defined $comment_thread_id
        ||
        $comment_thread_id !~ m/^\d+$/
        ||
        $comment_thread_id == 0
    )
    {
        my $comment_thread = Side7::UserContent::CommentThread->new(
                                                                    content_id    => $content_id,
                                                                    content_type  => ucfirst( $content_type ),
                                                                    thread_status => 'Open',
                                                                    created_at    => DateTime->now(),
                                                                    updated_at    => DateTime->now(),
                                                                   );
        $comment_thread->save;
        $comment_thread_id = $comment_thread->id;
    }

    my $remote_host   = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';

    my $new_comment = Side7::UserContent::Comment->new(
                                                        comment_thread_id => $comment_thread_id,
                                                        user_id           => session( 'user_id' ),
                                                        comment_type      => ucfirst( $comment_type ),
                                                        comment           => $comment,
                                                        private           => $private,
                                                        award             => $award,
                                                        ip_address        => request->address() . $remote_host,
                                                        created_at        => DateTime->now(),
                                                        updated_at        => DateTime->now(),
                                                      );
    $new_comment->save;

    # Award commenter Kudos Coins for the comment.
    my $description = 'Left a ' . $comment_type . ' on <a href="/user/' . $content->user->username . '">' .
                      $content->user->username . '\'s</a> ' . $content_type . ', "<a href="/' . lc( $content_type ) .
                      '/' . $content_id . '" target="_blank">' . $content->title . '</a>"';
    my $award_name = lc( $comment_type );
    $award_name =~ s/\s/_/g;
    my $kudos_award = Side7::KudosCoin->new(
                                            user_id     => session( 'user_id' ),
                                            amount      => $CONFIG->{'kudos_coins'}->{'award'}->{'leave_' . $award_name },
                                            description => $description,
                                            timestamp   => DateTime->now(),
                                            purchased   => 0,
    );
    $kudos_award->save;

    # Audit Log
    my $audit_message = 'New Comment Posted - <b>Successful</b><br>';
    $audit_message   .= 'User <b>' . session( 'username' ) . '</b> ( User ID: ' . session( 'user_id' ) . ' ) posted a comment';
    $audit_message   .= 'on ' . $content_type . ' belonging to User ' . $content->user->username . ' ( User ID: ' . $content->user_id . ' ).';
    $audit_message   .= '<br>User was awarded ' . $CONFIG->{'kudos_coins'}->{'award'}->{'leave_' . $award_name } . ' Kudos Coins.';
    my $new_value    .= '&gt;' . $new_comment->comment . '&lt;';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'New Comment on ' . $content_type . ' Posted',
                                          description    => $audit_message,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          original_value => undef,
                                          new_value      => $new_value,
                                          affected_id    => $content_id,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    my $commenter = Side7::User::get_user_by_id( session( 'user_id' ) );
    # Notify Content Owner of new comment.
    if
    (
        defined $content->user->user_preferences->comment_notifications
        &&
        $content->user->user_preferences->comment_notifications == 1
    )
    {
        my $msg_body = template 'pm_notifications/new_comment', {
                                                                content   => $content,
                                                                comment   => $new_comment,
                                                                commenter => $commenter,
                                                               }, { layout => 'pm_notifications' };

        my $subject = 'You have received a ' . $new_comment->comment_type . ' on your ' .
                       $content->content_type . ', "' . $content->title . '"!';

        my $pm = Side7::PrivateMessage->new(
                                            sender_id    => 0,
                                            recipient_id => $content->user_id,
                                            subject      => $subject,
                                            body         => $msg_body,
                                            status       => 'Delivered',
                                            created_at   => DateTime->now(),
                                           );
        $pm->save;

        my $email_body = template 'email/new_comment_notification', {
                                                                        content   => $content,
                                                                        comment   => $new_comment,
                                                                        commenter => $commenter,
                                                                    }, { layout => 'email' };

        email {
            from    => 'oni@side7.com',
            to      => $content->user->email_address,
            subject => $subject,
            body    => $email_body,
        };
    }

    # If this is a reply, notify the writer of the original comment that they have a response.
    if
    (
        defined $replied_to
        &&
        $replied_to =~ m/^\d+$/
    )
    {
        my $original_comment = Side7::UserContent::Comment->new( id => $replied_to );
        my $loaded = $original_comment->load( speculative => 1, with_objects => [ 'user' ] );

        if ( $loaded == 0 )
        {
            $LOGGER->warn( 'Unable to retrieve comment being replied to, to inform its author of a reply.' );
        }
        else
        {
            if
            (
                defined $original_comment->user->user_preferences->comment_notifications
                &&
                $original_comment->user->user_preferences->comment_notifications == 1
            )
            {
                my $msg_body = template 'pm_notifications/new_reply', {
                                                                        original_comment => $original_comment,
                                                                        content          => $content,
                                                                        comment          => $new_comment,
                                                                        commenter        => $commenter,
                                                                      }, { layout => 'pm_notifications' };

                my $subject = 'You have received a reply to your ' . $original_comment->comment_type . ' on ' .
                              $content->user->username . '\'s ' . $content->content_type . ', "' . $content->title . '"!';

                my $pm = Side7::PrivateMessage->new(
                                                    sender_id    => 0,
                                                    recipient_id => $original_comment->user_id,
                                                    subject      => $subject,
                                                    body         => $msg_body,
                                                    status       => 'Delivered',
                                                    created_at   => DateTime->now(),
                                                   );
                $pm->save;

                my $email_body = template 'email/new_reply_notification', {
                                                                            original_comment => $original_comment,
                                                                            content          => $content,
                                                                            comment          => $new_comment,
                                                                            commenter        => $commenter,
                                                                          }, { layout => 'email' };

                email {
                    from    => 'oni@side7.com',
                    to      => $content->user->email_address,
                    subject => $subject,
                    body    => $email_body,
                };
            }
        }
    }

    # Return
    flash message => 'Your comment has been saved.';
    return '<div>Saved!</div>';
};

# Alter visibility of a comment.
get qr{/([A-Za-z0-9]+)/([0-9]+)/comment/([0-9]+)/(show|hide)/?} => sub
{
    my ( $content_type, $content_id, $comment_id, $action ) = splat;

    # USER MUST BE LOGGED IN TO MANAGE COMMENT
    if ( ! defined session('logged_in') )
    {
        $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
        flash error => 'You must be logged in to modify a comment\'s visibility.';
        return forward '/login', { rd_url => "/$content_type/$content_id/comment/$comment_id/$action" };
    }

    if
    (
        lc( $content_type ) ne 'image'
        &&
        lc( $content_type ) ne 'music'
        &&
        lc( $content_type ) ne 'literature'
        &&
        lc( $content_type ) ne 'video'
    )
    {
        $LOGGER->warn( 'Invalid content_type provided: >' . $content_type . '<' );
        flash error => 'Could not find comments for the content you indicated; something went wrong.';
        return redirect '/';
    }

    if ( ! defined $content_id )
    {
        $LOGGER->warn( 'Invalid content_id provided: >' . $content_id . '<' );
        flash error => 'Could not find comments for the content you indicated; something went wrong.';
        return redirect '/';
    }

    if ( ! defined $comment_id )
    {
        $LOGGER->warn( 'Invalid comment_id provided: >' . $comment_id . '<' );
        flash error => 'Could not find the comment you wanted to modify; something went wrong.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    my $content = undef;
    if ( lc( $content_type ) eq 'video' )
    {
        #$content = Side7::UserContent::Video->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
        #$content = Side7::UserContent::Literature->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
        $content = Side7::UserContent::Music->new( id => $content_id );
    }
    else
    {
        $content = Side7::UserContent::Image->new( id => $content_id );
    }

    my $loaded = $content->load( speculative => 1, with_objects => [ 'user' ] );
    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not load the User Content that was requested: type: >' . $content_type .
                                                                                        '<, ID: >' . $content_id . '<' );
        flash error => 'Could not load the User Content you indicated; something went wrong.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    if ( $content->user_id ne session( 'user_id' ) )
    {
        $LOGGER->warn( 'User >' . session( 'username' ) . '< ( ID: ' . session( 'user_id' ) .
                       ') attempted to alter the visibility of a comment on content belonging to >' .
                       $content->user->username . '< (ID: ' . $content->user_id . ')' );
        flash error => 'This is not your content; you cannot change the visiblity of comments here.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    my $comment = Side7::UserContent::Comment->new( id => $comment_id );
    $loaded = $comment->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not load the Comment that was requested: ID: >' . $content_id . '<' );
        flash error => 'Could not load the Comment you indicated; something went wrong.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    $comment->private( ( lc( $action ) eq 'hide' ) ? 1 : 0 );
    $comment->save;

    my $state = ( lc( $action ) eq 'hide' ) ? 'Private' : 'Public';

    flash message => 'Successfully set the visibility of the comment to <strong>' . $state . '</strong>.';
    redirect '/' . $content_type . '/' . $content_id . '#' . $comment_id;
};

# Delete a comment.
get qr{/([A-Za-z0-9]+)/([0-9]+)/comment/([0-9]+)/delete/?} => sub
{
    my ( $content_type, $content_id, $comment_id, $action ) = splat;

    # USER MUST BE LOGGED IN TO MANAGE COMMENT
    if ( ! defined session('logged_in') )
    {
        $LOGGER->info( 'No session established while trying to reach >' . request->path_info . '<' );
        flash error => 'You must be logged in to delete a comment.';
        return forward '/login', { rd_url => "/$content_type/$content_id/comment/$comment_id/delete" };
    }

    # Is the content type a proper type?
    if
    (
        lc( $content_type ) ne 'image'
        &&
        lc( $content_type ) ne 'music'
        &&
        lc( $content_type ) ne 'literature'
        &&
        lc( $content_type ) ne 'video'
    )
    {
        $LOGGER->warn( 'Invalid content_type provided: >' . $content_type . '<' );
        flash error => 'Could not find comments for the content you indicated; something went wrong.';
        return redirect '/';
    }

    # Did we get a content ID?
    if ( ! defined $content_id )
    {
        $LOGGER->warn( 'Invalid content_id provided: >' . $content_id . '<' );
        flash error => 'Could not find comments for the content you indicated; something went wrong.';
        return redirect '/';
    }

    # Did we get a comment ID?
    if ( ! defined $comment_id )
    {
        $LOGGER->warn( 'Invalid comment_id provided: >' . $comment_id . '<' );
        flash error => 'Could not find the comment you wanted to modify; something went wrong.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    my $content = undef;
    if ( lc( $content_type ) eq 'video' )
    {
        #$content = Side7::UserContent::Video->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'literature' )
    {
        #$content = Side7::UserContent::Literature->new( id => $content_id );
    }
    elsif ( lc( $content_type ) eq 'music' )
    {
        $content = Side7::UserContent::Music->new( id => $content_id );
    }
    else
    {
        $content = Side7::UserContent::Image->new( id => $content_id );
    }

    # Can we load the indicated content?
    my $loaded = $content->load( speculative => 1, with_objects => [ 'user' ] );
    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not load the User Content that was requested: type: >' . $content_type .
                                                                                        '<, ID: >' . $content_id . '<' );
        flash error => 'Could not load the User Content you indicated; something went wrong.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    # Is the current user the owner of the content?
    if ( $content->user_id ne session( 'user_id' ) )
    {
        $LOGGER->warn( 'User >' . session( 'username' ) . '< ( ID: ' . session( 'user_id' ) .
                       ') attempted to delete a comment on content belonging to >' .
                       $content->user->username . '< (ID: ' . $content->user_id . ')' );
        flash error => 'This is not your content; you cannot delete comments here.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    # Does the comment exist?
    my $comment = Side7::UserContent::Comment->new( id => $comment_id );
    $loaded = $comment->load( speculative => 1 );

    if ( $loaded == 0 )
    {
        $LOGGER->warn( 'Could not load the Comment that was requested: ID: >' . $content_id . '<' );
        flash error => 'Could not find the Comment you indicated; something went wrong.';
        return redirect '/' . $content_type . '/' . $content_id;
    }

    # Fetch the comment count from the thread.
    my $comment_thread_id = $comment->comment_thread_id;
    my $comment_count = Side7::UserContent::Comment::Manager->get_comments_count(
                                                                            query => [
                                                                                        comment_thread_id => $comment->comment_thread_id,
                                                                                     ],
    ) // 0;

    # Delete the comment.
    $comment->delete;

    # Kill the comment thread if we just deleted the only comment.
    if ( $comment_count == 1 )
    {
        my $comment_thread = Side7::UserContent::CommentThread->new( id => $comment_thread_id );
        my $loaded = $comment_thread->load( speculative => 1 );

        if ( $loaded == 0 )
        {
            $LOGGER->warn( 'Could not delete comment_thread >' . $comment_thread_id . '<; Could not load it from the database.' );
        }
        else
        {
            $comment_thread->delete;
        }
    }

    flash message => 'Successfully deleted the comment.';
    redirect '/' . $content_type . '/' . $content_id . '#t' . $comment_thread_id;
};

#############################################
### User Dashboard Pages requiring logins ###
#############################################

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
                                                             );

            if ( $authorized != 1 )
            {
                $LOGGER->info( 'User >' . session( 'username' ) . '< not authorized to view >' . request->path_info . '<' );
                flash error => 'You are not authorized to view that page.';
                return redirect '/'; # Not an authorized page.
            }

            my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

            if ( ! defined $user || ref( $user ) ne 'Side7::User' )
            {
                flash error => 'You are either not logged in or your account could not be accessed.';
                return redirect '/'; # Not an authorized page.
            }

            var activity_log => $user->get_activity_logs();

            set layout => 'my';
        }
    }
};

# User Home Page
get '/my/home/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    my ( $user_hash ) = Side7::User::show_home( username => session( 'username' ) );

    template 'my/home', { data => $user_hash, activity_log => vars->{'activity_log'} };
};

# User Account Management Landing Page
get '/my/account/?' => sub
{
    my $user = Side7::User::show_account( username => session( 'username' ) );

    template 'my/account', { user => $user, activity_log => vars->{'activity_log'} };
};

# User Avatar Modification Page
get '/my/avatar/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $system_avatars = Side7::User::Avatar::SystemAvatar->get_all_system_avatars( size => 'small' );
    my $user_avatars   = $user->get_all_avatars( size => 'small' );

    template 'my/avatar', {
                            user           => $user,
                            system_avatars => $system_avatars,
                            user_avatars   => $user_avatars,
                            activity_log   => vars->{'activity_log'},
                          };
};

# User Avatar Upload
post '/my/avatar/upload/?' => sub
{
    # Validating upload
    my $err_message = '';
    if ( ! defined params->{'filename'} )
    {
        $err_message .= "You have errors that need to be corrected:<br />";
        $err_message .= 'You must provide a file to be uploaded.<br>';

        flash error => $err_message;
        return redirect '/my/avatar';
    }

    # Get User & Content Path
    my $user = Side7::User::get_user_by_username( session( 'username' ) );
    my ( $success, $error ) = Side7::Utils::File::create_user_directory( session( 'user_id' ) );
    if ( defined $error )
    {
        flash error => $error;
        return redirect '/my/avatar';
    }

    my $upload_dir = $user->get_avatar_directory();

    # If filename exists, bail with an error message.
    if
    (
        -f $upload_dir . params->{'filename'}
    )
    {
        my $err_message = 'You already have an avatar with the filename <b>&apos;' . params->{'filename'} . '&apos;</b>.<br />';

        flash error => $err_message;
        return redirect '/my/avatar';
    }

    # Upload the file
    my $file = request->upload( 'filename' );

    # Copy file to the User's directory
    $file->copy_to( $upload_dir . $file->filename() );

    my $remote_host   = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_message = '';
    my $new_values    = '';

    # Insert the content record into the database.
    my $file_stats = Side7::Utils::Image::get_image_stats( image => $upload_dir . $file->filename(), dimensions => 1 );
    if ( defined $file_stats->{'error'} )
    {
        $LOGGER->warn( 'ERROR GETTING IMAGE STATS: ' . $file_stats->{'error'} );
        flash error => 'Invalid file format has been uploaded as an image.';
        return redirect '/my/avatar';
    }

    my $now = DateTime->now();

    my $avatar = Side7::User::Avatar::UserAvatar->new(
                                                        user_id           => $user->id(),
                                                        filename          => params->{'filename'},
                                                        title             => params->{'title'},
                                                        created_at        => $now,
                                                        updated_at        => $now,
                                                     );

    $avatar->save();

    # Set Avatar to the newly uploaded one.
    $user->account->avatar_id( $avatar->id() );
    $user->account->avatar_type( 'Image' );
    $user->account->updated_at( $now );
    $user->account->save();

    # Record Audit Message
    $audit_message  = 'User &gt;<b>' . session( 'username' ) . '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ) uploaded a new Avatar';
    $new_values     = 'Filename: &gt;' . params->{'filename'} . '&lt;<br />';
    $new_values    .= 'Title: &gt;' . params->{'title'} . '&lt;<br />';
    $new_values    .= 'Created_at: &gt;' . $now . '&lt;<br />';
    $new_values    .= 'Updated_at: &gt;' . $now . '&lt;<br />';

    my $audit_log = Side7::AuditLog->new(
                                          title       => 'New User Avatar Uploaded',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          new_value   => $new_values,
                                          timestamp   => DateTime->now(),
    );

    $audit_log->save();

    my $activity_log = Side7::ActivityLog->new(
                                                user_id    => session( 'user_id' ),
                                                activity   => '<a href="/user/' . session( 'username' ) . '">' . session( 'username' ) .
                                                              '</a> updated ' .
                                                              Side7::Utils::Text::get_pronoun(
                                                                                                sex            => $user->account->sex(),
                                                                                                part_of_speech => 'poss_pronoun',
                                                                                             )
                                                              . ' avatar.',
                                                created_at => DateTime->now(),
    );
    $activity_log->save();

    my $avatar_name = ( defined params->{'title'} ) ? params->{'title'} : params->{'filename'};
    flash message => 'Hooray! Your Avatar <b>' . $avatar_name . '</b> has been uploaded successfully.';
    redirect '/my/avatar';
};

# Select A New Avatar Action
post '/my/avatar/select/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $avatar_type = params->{'avatar_type'} // undef;
    my $avatar_id   = params->{'avatar_id'}   // undef;

    # Simple validation that we have the two required fields
    if ( ! defined $avatar_type || $avatar_type eq '' )
    {
        flash error => 'Something when wrong! We could not update your Avatar!';
        $LOGGER->warn( 'Undefined avatar_type when selecting Avatar.' );
        return redirect '/my/avatar';
    }

    if
    (
        defined $avatar_type
        &&
        (
            lc( $avatar_type ) eq 'system'
            ||
            lc( $avatar_type ) eq 'image'
        )
        &&
        (
            ! defined $avatar_id
            ||
            $avatar_id eq ''
        )
    )
    {
        flash error => 'Something when wrong! We could not update your Avatar!';
        $LOGGER->warn( 'Undefined avatar_id when selecting an Image or System Avatar.' );
        return redirect '/my/avatar';
    }

    # If avatar_type is not "System" or "Image", ignore the avatar_id
    # Otherwise, double-check the leading character on the avatar_id matches the avatar_type
    # Leading character has precedence over avatar_type, just in case the javascript
    # failed to change the type automatically.

    my $audit_message  = 'User &gt;<b>' . session( 'username' ) . '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ) selected a new Avatar';
    my $old_values  = '';
    if ( lc( $avatar_type ) eq 'system' || lc( $avatar_type ) eq 'image' || defined $user->account->avatar_id )
    {
        $old_values  = 'avatar_id: &gt;' . $user->account->avatar_id() . '&lt;<br>';
    }
    $old_values    .= 'avatar_type: &gt;' . $user->account->avatar_type() . '&lt;<br>';
    my $new_values = '';

    if
    (
        lc( $avatar_type ) eq 'system'
        ||
        lc( $avatar_type ) eq 'image'
    )
    {
        my %initials = ( u => 'Image', s => 'System' );
        my ( $type_initial, $new_avatar_id ) = split( /-/, $avatar_id );
        if ( $avatar_type ne $initials{$type_initial} )
        {
            $avatar_type = $initials{$type_initial};
        }

        # If it's a User Avatar, retrieve avatar from DB, ensure it belongs to the User.
        if ( lc( $avatar_type ) eq 'image' )
        {
            my $avatar = Side7::User::Avatar::UserAvatar->new( id => $new_avatar_id )->load( speculative => 1 );
            if ( ! defined $avatar || ref( $avatar ) ne 'Side7::User::Avatar::UserAvatar' )
            {
                flash error => 'The Avatar you are trying to use could not be retrieved.';
                return redirect '/my/avatar';
            }
            if ( $avatar->user_id() != $user->id() )
            {
                flash error => 'The Avatar you are trying to use does not belong to your Account.';
                return redirect '/my/avatar';
            }
        }

        $user->account->avatar_id( $new_avatar_id );
        $new_values .= 'avatar_id: &gt;' . $new_avatar_id . '&lt;<br>';
    }

    if ( $avatar_type ne $user->account->avatar_type() )
    {
        $new_values .= 'avatar_type: &gt;' . $avatar_type . '&lt;<br>';
        $user->account->avatar_type( $avatar_type );
    }

    # Update the User.
    $user->account->save();

    # Audit Log
    my $remote_host   = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'New User Avatar Selected',
                                          description    => $audit_message,
                                          ip_address     => request->address() . $remote_host,
                                          original_value => $old_values,
                                          new_value      => $new_values,
                                          affected_id    => $user->id(),
                                          timestamp      => DateTime->now(),
    );

    $audit_log->save();

    my $activity_log = Side7::ActivityLog->new(
                                                user_id    => session( 'user_id' ),
                                                activity   => '<a href="/user/' . session( 'username' ) . '">' . session( 'username' ) .
                                                              '</a> updated ' .
                                                              Side7::Utils::Text::get_pronoun(
                                                                                                sex            => $user->account->sex(),
                                                                                                part_of_speech => 'poss_pronoun',
                                                                                             )
                                                              . ' avatar.',
                                                created_at => DateTime->now(),
    );
    $activity_log->save();

    # Return
    flash message => 'Your Avatar has been successfully updated!';
    redirect '/my/avatar';
};

# User Avatar Delete

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

    my $confirmation_code = Side7::Utils::Crypt::sha1_hex_encode( session( 'username' ) . time() );
    my $confirmation_link = uri_for( "/my/confirm_password_change/$confirmation_code" );

    # Record change to be made in a temp record
    my $password_change = Side7::User::ChangePassword->new(
                                                            user_id           => session( 'user_id' ),
                                                            confirmation_code => $confirmation_code,
                                                            new_password      => params->{'new_password'},
                                                            is_a_reset        => 0,
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

    my $audit_message = 'Password Change Request Sent<br>';
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
    return template 'my/password_change_next_step', { user => $user, activity_log => vars->{'activity_log'} };
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
    $audit_message   .= 'Confirmation Code: &gt;<b>' . params->{'confirmation_code'} . '</b>&lt;';
    my $old_value    .= '&gt;' . $change_result->{'original_password'} . '&lt;';
    my $new_value    .= '&gt;' . $change_result->{'new_password'} . '&lt;';
    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Password Change Confirmation',
                                          description    => $audit_message,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          original_value => $old_value,
                                          new_value      => $new_value,
                                          affected_id    => session( 'user_id' ),
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    template 'my/password_change_confirmed', { activity_log => vars->{'activity_log'} };
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

    my $audit_message = 'Set Account Delete Flag Request Sent<br>';
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
    return template 'my/set_delete_flag_next_step', { user => $user, activity_log => vars->{'activity_log'} };
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

    my $audit_message = 'Set Delete Flag confirmation - <b>Successful</b><br>';
    $audit_message   .= 'Confirmation Code: &gt;<b>' . params->{'confirmation_code'} . '</b>&lt;<br>';
    $audit_message   .= 'Delete On: &gt;<b>' . $change_result->{'delete_on'} . '</b>&lt;';
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

    template 'my/set_delete_flag_confirmed', { delete_on => $change_result->{'delete_on'}, activity_log => vars->{'activity_log'} };
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
        return template 'my/account', { activity_log => vars->{'activity_log'} };
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
                             activity_log        => vars->{'activity_log'},
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
    my $audit_msg = 'User Profile Updated - <b>Successful</b><br>' .
                    'Profile for &gt;<b>' . $user->username() . '</b>&lt; ( User ID: ' . params->{'user_id'} . ' )<br>' .
                    'updated by &gt;' . session( 'username' ) . '&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
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

    my $activity_log = Side7::ActivityLog->new(
                                                user_id    => session( 'user_id' ),
                                                activity   => '<a href="/user/' . session( 'username' ) . '">' . session( 'username' ) .
                                                              '</a> updated ' .
                                                              Side7::Utils::Text::get_pronoun(
                                                                                                sex            => $user->account->sex(),
                                                                                                part_of_speech => 'poss_pronoun',
                                                                                             )
                                                              . ' profile.',
                                                created_at => DateTime->now(),
    );
    $activity_log->save();

    # Return
    my $new_is_public_hash  = $user->account->get_is_public_hash();
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
                             is_public_hash      => $new_is_public_hash,
                             activity_log        => vars->{'activity_log'},
                           };
};

# User View Friends
get '/my/friends/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $approved_friends = $user->get_friends_by_status( status => 'Approved' );

    my $pending_requests = $user->get_pending_friend_requests();

    template 'my/friends', {
                            user             => $user,
                            friends          => $approved_friends,
                            pending_requests => $pending_requests,
                            activity_log     => vars->{'activity_log'},
                           };
};

# User Send Friend Request
get '/friend_link/:username' => sub
{
    my $rd_url = Side7::Login::sanitize_redirect_url(
        {
            rd_url   => params->{'rd_url'},
            referer  => request->referer,
            uri_base => request->uri_base
        }
    );

    my $user      = Side7::User::get_user_by_id( session( 'user_id' ) );
    my $recipient = Side7::User::get_user_by_username( params->{'username'} );

    if ( ! defined $recipient || ref( $recipient ) ne 'Side7::User' )
    {
        flash error => 'Cannot send a Friend Link request to a non-existent User.';
        return redirect $rd_url;
    }

    # Check to ensure that the User is allowed to send a Friend Request
    my $send_permission = $user->can_send_friend_request_to_user( user_id => $recipient->id );

    if ( $send_permission->{'can_send'} != 1 )
    {
        flash error => 'Unable to send a Friend Link Request to <b>' . $recipient->username . '</b>.<br>' . $send_permission->{'error'};
        return redirect $rd_url;
    }

    my $friend_request = Side7::User::Friend->new(
                                                    user_id    => session( 'user_id' ),
                                                    friend_id  => $recipient->id,
                                                    status     => 'Pending',
                                                    created_at => DateTime->now(),
                                                    updated_at => DateTime->now(),
                                                 );
    $friend_request->save();

    # Audit Log
    my $audit_msg = 'Friend Link Request Sent - <b>Successful</b><br>';
    $audit_msg   .= 'User &gt;<b>' . $user->username . '</b>&lt; ( User ID: ' . $user->id . ' ) has sent a<br>';
    $audit_msg   .= 'friend link request to User &gt;' . $recipient->username . '&lt; ( User ID: ' . $recipient->id . ' ).';

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Friend Link Request Sent',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $recipient->id,
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return
    flash message => 'Sent your Friend Link request to <b>' . $recipient->username . '</b>!';
    return redirect $rd_url;
};

# User Friend Request Responses
## Accept  ( Friend request accepted )
get '/my/friends/:user_id/accept' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $pending_requests = $user->get_pending_friend_requests( user_id => params->{'user_id'} );

    my $pending_request = $pending_requests->[0];

    if ( ! defined $pending_request || $pending_request->user_id ne params->{'user_id'} )
    {
        flash error => 'The pending friend request you indicated either does not belong to your account, or does not exist.';
        return redirect '/my/friends';
    }

    # Reset the status on pending request.
    $pending_request->status( 'Approved' );
    $pending_request->updated_at( DateTime->now() );
    $pending_request->save();

    # Create reciprocal link
    my $reciprocal_link = Side7::User::Friend->new(
                                                    user_id    => $user->id,
                                                    friend_id  => params->{'user_id'},
                                                    status     => 'Approved',
                                                    created_at => DateTime->now(),
                                                    updated_at => DateTime->now(),
    );
    $reciprocal_link->save();

    # TODO: Send notification to Request Sender that request was approved

    # Audit Log
    my $audit_msg = 'Friend Request Approved - <b>Successful</b><br>';
    $audit_msg .= 'User &gt;<b>' . $user->username . '</b>&lt; ( User ID: ' . $user->id . ' ) approved<br>';
    $audit_msg .= 'a friend request from &gt;' . $pending_request->user->username . '&lt; ( User ID: ' . $pending_request->user_id . ').<br>';
    $audit_msg .= 'Reciprocal link established.';

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Friend Request Approved',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $pending_request->id(),
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Activity Logs
    my $activity_log1 = Side7::ActivityLog->new(
                                                user_id    => session( 'user_id' ),
                                                activity   => '<a href="/user/' . session( 'username' ) . '">' . session( 'username' ) .
                                                              '</a> became friends with <a href="/user/' . $pending_request->user->username . '">' .
                                                              $pending_request->user->username . '</a>.',
                                                created_at => DateTime->now(),
    );
    $activity_log1->save();
    my $activity_log2 = Side7::ActivityLog->new(
                                                user_id    => $pending_request->user_id,
                                                activity   => '<a href="/user/' . $pending_request->user->username  . '">' .
                                                              $pending_request->user->username . '</a> became friends with <a href="/user/' .
                                                              session( 'username' ) . '">' . session( 'username' ) . '</a>.',
                                                created_at => DateTime->now(),
    );
    $activity_log2->save();

    # Return
    flash message => 'Friend request from <b>' . $pending_request->user->username . '</b> Approved!';
    redirect '/my/friends';
};

## Ignore ( Sender not notitifed, future friend requests possible. )
get '/my/friends/:user_id/ignore' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $pending_requests = $user->get_pending_friend_requests( user_id => params->{'user_id'} );

    my $pending_request = $pending_requests->[0];

    if ( ! defined $pending_request || $pending_request->user_id ne params->{'user_id'} )
    {
        flash error => 'The pending friend request you indicated either does not belong to your account, or does not exist.';
        return redirect '/my/friends';
    }

    # Reset the status on pending request.
    $pending_request->status( 'Ignored' );
    $pending_request->updated_at( DateTime->now() );
    $pending_request->save();

    # Audit Log
    my $audit_msg = 'Friend Request Ignored - <b>Successful</b><br>';
    $audit_msg .= 'User &gt;<b>' . $user->username . '</b>&lt; ( User ID: ' . $user->id . ' ) ignored<br>';
    $audit_msg .= 'a friend request from &gt;' . $pending_request->user->username . '&lt; ( User ID: ' . $pending_request->user_id . ').<br>';

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Friend Request Ignored',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $pending_request->id(),
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return
    flash message => 'Friend request from <b>' . $pending_request->user->username . '</b> Ignored!';
    redirect '/my/friends';
};

## Deny ( Sender notified, Future friend requests blocked )
get '/my/friends/:user_id/deny' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $pending_requests = $user->get_pending_friend_requests( user_id => params->{'user_id'} );

    my $pending_request = $pending_requests->[0];

    if ( ! defined $pending_request || $pending_request->user_id ne params->{'user_id'} )
    {
        flash error => 'The pending friend request you indicated either does not belong to your account, or does not exist.';
        return redirect '/my/friends';
    }

    # Reset the status on pending request.
    $pending_request->status( 'Denied' );
    $pending_request->updated_at( DateTime->now() );
    $pending_request->save();

    # TODO: Notify the Friend Request Sender that their request was denied, and that they will not be able to make
    #       additional requests in the future.

    # Audit Log
    my $audit_msg = 'Friend Request Denied - <b>Successful</b><br>';
    $audit_msg .= 'User &gt;<b>' . $user->username . '</b>&lt; ( User ID: ' . $user->id . ' ) denied<br>';
    $audit_msg .= 'a friend request from &gt;' . $pending_request->user->username . '&lt; ( User ID: ' . $pending_request->user_id . ').<br>';

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Friend Request Denied',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $pending_request->id(),
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return
    flash message => 'Friend request from <b>' . $pending_request->user->username . '</b> Denied!';
    redirect '/my/friends';
};

# User Remove Friend Link
get '/my/friends/:username/dissolve' => sub
{
    my $rd_url = Side7::Login::sanitize_redirect_url(
        {
            rd_url   => params->{'rd_url'},
            referer  => request->referer,
            uri_base => request->uri_base
        }
    );

    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );
    my $target = Side7::User::get_user_by_username( params->{'username'} );

    if ( ! defined $user || ref( $user ) ne 'Side7::User' )
    {
        flash error => 'Either you are not logged in, or your account can not be found.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    if ( ! defined $target || ref( $target ) ne 'Side7::User' )
    {
        flash error => 'Error in attempting to dissolve the friend link with >' . $target . '<.';
        return redirect '/'; # TODO: REDIRECT TO USER-NOT-FOUND.
    }

    my $friends = $user->get_friends_by_id( user_ids => [ $target->id ] );

    my $friend = $friends->[0];

    if ( ! defined $friend || $friend->friend_id ne $target->id )
    {
        flash error => 'The friend link you indicated either does not belong to your account, or does not exist.';
        return redirect '/my/friends';
    }

    # Delete the link to the friend.
    $friend->delete();

    # Delete reciprocal link
    my $reciprocal_friends = $target->get_friends_by_id( user_ids => [ session( 'user_id' ) ] );
    my $reciprocal_friend = $reciprocal_friends->[0];

    if ( defined $reciprocal_friend && $reciprocal_friend->friend_id == session( 'user_id' ) )
    {
        $reciprocal_friend->delete();
    }

    # Audit Log
    my $audit_msg = 'Friend Link Dissolved - <b>Successful</b><br>';
    $audit_msg .= 'User &gt;<b>' . $user->username . '</b>&lt; ( User ID: ' . $user->id . ' ) dissolved<br>';
    $audit_msg .= 'their friend link with &gt;' . $target->username . '&lt; ( User ID: ' . $target->id . ').<br>';

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Friend Link Dessolved',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $friend->id(),
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return
    flash message => 'Friend Link with <b>' . $target->username . '</b> Dissolved!';
    redirect $rd_url;
};

# User Gallery Landing Page
get '/my/gallery/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    # Fetch Gallery Stats
    my ( $user_hash ) = Side7::User::show_gallery( username => session( 'username' ) );

    template 'my/gallery', { data => $user_hash, activity_log => vars->{'activity_log'} };
};

# User Kudos Landing Page
get '/my/kudos/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    my ( $user_hash ) = Side7::User::show_kudos( username => session( 'username' ) );

    template 'my/kudos', { data => $user_hash, activity_log => vars->{'activity_log'} };
};

# User Album Pages
## Create New Album Form
get '/my/albums/new/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    template 'my/album_new', { user => $user }, { layout => 'my_lightbox' };
};

## Submit New Album Action
post '/my/albums/new' => sub
{
    my $album_name        = params->{'name'}          // undef;
    my $album_description = params->{'description'}   // undef;
    my $album_artwork     = params->{'album_artwork'} // undef;
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    # Simple validation
    if ( ! defined $album_name )
    {
        flash error => 'ERROR: You need to define a Name for this Album.';
        return template 'my/album_new', { user => $user, album => params }, { layout => 'my_lightbox' };
    }

    my $new_album = Side7::UserContent::Album->new(
                                                    user_id     => $user->id(),
                                                    name        => $album_name,
                                                    description => $album_description,
                                                    system      => 0,
                                                    created_at  => DateTime->now(),
                                                    updated_at  => DateTime->now(),
                                                  );
    $new_album->save();

    if ( defined $album_artwork )
    {
        my $upload_dir = $user->get_album_artwork_directory();

        $LOGGER->debug( 'UPLOAD DIR: >' . $upload_dir . '<' );

        # Upload the file
        my $file = request->upload( 'album_artwork' );

        # Copy file to the User's directory
        $file->copy_to( $upload_dir . $file->filename() );

        my $new_artwork = Side7::UserContent::AlbumArtwork->new(
                                                                album_id   => $new_album->id,
                                                                filename   => $file->filename(),
                                                                created_at => DateTime->now(),
                                                                updated_at => DateTime->now(),
                                                               );

        $new_artwork->save();
    }

    # Audit Log
    my $audit_msg = 'Custom Album Created - <b>Successful</b><br>' .
                    'Album owned by &gt;<b>' . $user->username() . '</b>&lt; ( User ID: ' . $user->id() . ' )<br>' .
                    'created by &gt;' . session( 'username' ) . '&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
    if ( defined $album_artwork )
    {
        $audit_msg .= 'Artwork Added: &gt;' . $album_artwork . '&lt;.<br>';
    }

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Custom Album Updated',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $new_album->id(),
                                          original_value => undef,
                                          new_value      => 'name: &gt;' . $new_album->name() .
                                                            '&lt;<br>description: &gt;' . $new_album->description() . '&lt;<br>' .
                                                            'artwork: &gt;' . $album_artwork . '&lt;',
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    flash message => 'Your new Album "<strong>' . $new_album->name() . '</strong>" was successfully created!';
    redirect '/my/albums/' . $new_album->id() . '/manage';
};

# Delete Album Confirm
get '/my/albums/:album_id/delete/?' => sub
{
    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $album  = Side7::UserContent::Album->new( id => params->{'album_id'} );
    my $loaded = $album->load( speculative => 1 );

    if ( $loaded == 0 || ref( $album ) ne 'Side7::UserContent::Album' )
    {
        flash error => 'The Album you tried to delete either could not be found or does not exist.';
        return redirect '/my/albums';
    }

    if ( session( 'user_id' ) != $album->user_id() )
    {
        flash error => 'The Album you tried to delete does not belong to your Account.';
        return redirect '/my/albums';
    }

    template 'my/album_delete_confirm', { album => $album }, { layout => 'my_lightbox' };
};

# Delete Album Action
get '/my/albums/:album_id/delete_confirmed/?' => sub
{
    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $album  = Side7::UserContent::Album->new( id => params->{'album_id'} );
    my $loaded = $album->load( speculative => 1 );

    if ( $loaded == 0 || ref( $album ) ne 'Side7::UserContent::Album' )
    {
        flash error => 'The Album you tried to delete either could not be found or does not exist.';
        return redirect '/my/albums';
    }

    if ( session( 'user_id' ) != $album->user_id() )
    {
        flash error => 'The Album you tried to delete does not belong to your Account.';
        return redirect '/my/albums';
    }

    my $original_album = $album->clone();
    my $affected_user  = Side7::User::get_user_by_id( $original_album->user_id() );

    if ( defined $album->artwork )
    {
        my ( $success, $error ) = $album->delete_album_artwork;
        if ( defined $error && $error ne '' )
        {
            $LOGGER->warn( 'Album Artwork for Album >' . $album->name . '< (ID: ' . $album->id .
                            ' ) could not be deleted: ' . $error );
        }
        else
        {
            # Audit Log
            my $audit_msg = 'Album Artwork Deleted - <b>Successful</b><br>';
            $audit_msg   .= 'The Album Artwork for Album &gt;' . $original_album->name() . '&lt; ( Album ID: ' .
                            $original_album->id() .  ' ) owned by<br>';
            $audit_msg   .= 'User &gt;' . $affected_user->username() . '&lt; ( User ID: ' . $affected_user->id() .
                            ' ) has been deleted<br>';
            $audit_msg   .= 'by User &gt;<b>' . $user->username() . '</b>&lt; ( User ID: ' . $user->id() . ' ).<br>';

            my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
            my $audit_log = Side7::AuditLog->new(
                                                  title          => 'Album Artwork Deleted',
                                                  description    => $audit_msg,
                                                  ip_address     => request->address() . $remote_host,
                                                  user_id        => session( 'user_id' ),
                                                  affected_id    => $original_album->id(),
                                                  original_value => undef,
                                                  new_value      => undef,
                                                  timestamp      => DateTime->now(),
            );
            $audit_log->save();
        }
    }

    # Remove Album Mappings
    $album->images( [] );
    $album->music( [] );
    # TODO: Delete literature
    # $album->literature( [] );
    $album->save();

    # Remove Album Record
    $album->delete();

    # Audit Log
    my $audit_msg = 'Custom Album Deleted - <b>Successful</b><br>';
    $audit_msg   .= 'The Album &gt;' . $original_album->name() . '&lt; ( Album ID: ' . $original_album->id() . ' ) owned by<br>';
    $audit_msg   .= 'User &gt;' . $affected_user->username() . '&lt; ( User ID: ' . $affected_user->id() . ' ) has been deleted<br>';
    $audit_msg   .= 'by User &gt;<b>' . $user->username() . '</b>&lt; ( User ID: ' . $user->id() . ' ).<br>';

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Custom Album Deleted',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => $original_album->id(),
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();
    # Return

    flash message => 'Your Album <strong>' . $original_album->name() . '</strong> was deleted.';
    redirect '/my/albums';
};


## Existing Album Listing
get '/my/albums/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $albums = $user->get_albums();

    template 'my/albums', { user => $user, albums => $albums }, { layout => 'my_lightbox' };
};

## Modify Album Form
get '/my/albums/:album_id/edit' => sub
{
    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $album  = Side7::UserContent::Album->new( id => params->{'album_id'} );
    my $loaded = $album->load( speculative => 1, with_objects => [ 'artwork' ] );

    if ( $loaded == 0 || ref( $album ) ne 'Side7::UserContent::Album' )
    {
        flash error => 'The Album you tried to access either could not be found or does not exist.';
        return redirect '/my/albums';
    }

    if ( session( 'user_id' ) != $album->user_id() )
    {
        flash error => 'The Album you tried to access does not belong to your Account.';
        return redirect '/my/albums';
    }

    template 'my/album_edit', { album => $album }, { layout => 'my_lightbox' };
};

## Submit Edited Album Action
post '/my/albums/:album_id/save' => sub
{
    my $params = params;
    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $original_album  = Side7::UserContent::Album->new( id => params->{'album_id'} );
    my $loaded = $original_album->load( speculative => 1 );

    if ( $loaded == 0 || ref( $original_album ) ne 'Side7::UserContent::Album' )
    {
        flash error => 'The Album you tried to access either could not be found or does not exist.';
        return redirect '/my/albums';
    }

    if ( session( 'user_id' ) != $original_album->user_id() )
    {
        flash error => 'The Album you tried to access does not belong to your Account.';
        return redirect '/my/albums';
    }

    my $affected_user = Side7::User::get_user_by_id( $original_album->user_id() );

    my $updated_album = $original_album->clone();

    # Validate form values
    my $data = validator( $params, 'album_edit_form.pl' );

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
        return template '/my/album_edit', { album => $params }, { layout => 'my_lightbox' };
    }

    # Save album information
    my $updated_fields  = '';
    my $original_values = '';
    my $updated_values  = '';
    my $updated         = 0;
    foreach my $key ( qw/ name description / )
    {
        if
        (
            ! defined params->{$key} && defined $original_album->$key()
            ||
            defined params->{$key} && ! defined $original_album->$key()
            ||
            params->{$key} ne $original_album->$key()
        )
        {
            $updated_album->$key( params->{$key} );
            $updated = 1;
            $updated_fields  .= '>' . $key . '<, ';
            $original_values .= "$key: >" . $original_album->$key() . "<\n";
            $updated_values  .= "$key: >" . params->{$key} . "<\n";
        }
    }

    if ( $updated == 1 )
    {
        $updated_album->updated_at( DateTime->now() );
        $updated_album->save();
    }

    if ( defined params->{album_artwork} )
    {
        my $upload_dir = $user->get_album_artwork_directory();

        $LOGGER->debug( 'UPLOAD DIR: >' . $upload_dir . '<' );

        if ( defined $updated_album->artwork )
        {
            my ( $success, $error ) = $updated_album->delete_album_artwork();
            if ( defined $error && $error ne '' )
            {
                $LOGGER->warn( 'Could not delete previous album artwork for album >' . $updated_album->name . '<: ' . $error );
            }
        }

        # Upload the file
        my $file = request->upload( 'album_artwork' );

        # Copy file to the User's directory
        $file->copy_to( $upload_dir . $file->filename() );

        my $new_artwork = Side7::UserContent::AlbumArtwork->new(
                                                                album_id   => $updated_album->id,
                                                                filename   => $file->filename(),
                                                                created_at => DateTime->now(),
                                                                updated_at => DateTime->now(),
                                                               );

        $new_artwork->save();
    }

    # Audit Log
    my $audit_msg = 'Custom Album Updated - <b>Successful</b><br>' .
                    'Album owned by &gt;' . $affected_user->username() . '&lt; ( User ID: ' . $affected_user->id() . ' )' .
                    ' updated by &gt;<b>' . session( 'username' ) . '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
    $audit_msg .= 'Fields changed:<br>' . $updated_fields;

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'Custom Album Updated',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => params->{'album_id'},
                                          original_value => $original_values,
                                          new_value      => $updated_values,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    # Return
    my $albums = $affected_user->get_albums();

    flash message => 'Your Album, <strong>' . $updated_album->name() . '</strong>, has been successfully updated!';
    template 'my/albums', { user => $affected_user, albums => $albums }, { layout => 'my_lightbox' };
};

## Manage Album Content Form
get '/my/albums/:album_id/manage' => sub
{
    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $album  = Side7::UserContent::Album->new( id => params->{'album_id'} );
    my $loaded = $album->load( speculative => 1 );

    if ( $loaded == 0 || ref( $album ) ne 'Side7::UserContent::Album' )
    {
        flash error => 'The Album you tried to access either could not be found or does not exist.';
        return redirect '/my/albums';
    }

    if ( session( 'user_id' ) != $album->user_id() )
    {
        flash error => 'The Album you tried to access does not belong to your Account.';
        return redirect '/my/albums';
    }

    my $album_content = $album->get_content( sort_by => 'title', sort_order => 'asc' );
    my $all_content   = $user->get_all_content( sort_by => 'title asc' );

    my $unassociated_content = [];
    foreach my $content_item ( @$all_content )
    {
        if
        (
            List::MoreUtils::none {
                                    $_->content_type() eq $content_item->content_type()
                                    &&
                                    $_->title() eq $content_item->title()
                                    &&
                                    $_->created_at() eq $content_item->created_at()
                                  }
            @$album_content
        )
        {
            push( @$unassociated_content, $content_item );
        }
    }

    template 'my/album_content', {
                                    album                => $album,
                                    album_content        => $album_content,
                                    unassociated_content => $unassociated_content,
                                 },
                                 { layout => 'my_lightbox' };
};

## Submit Album Content Action
post '/my/albums/:album_id/manage' => sub
{
    my $params            = params;
    my $content_to_add    = [];
    my $content_to_remove = [];

    if ( ref ( params->{'content_add'} ) eq 'ARRAY' )
    {
        push( @$content_to_add, @{ params->{'content_add'} } );
    }
    else
    {
        push( @$content_to_add, params->{'content_add'} ) if params->{'content_add'};
    }
    if ( ref ( params->{'content_remove'} ) eq 'ARRAY' )
    {
        push( @$content_to_remove, @{ params->{'content_remove'} } );
    }
    else
    {
        push( @$content_to_remove, params->{'content_remove'} ) if params->{'content_remove'};
    }

    my $user   = Side7::User::get_user_by_id( session( 'user_id' ) );

    my $album  = Side7::UserContent::Album->new( id => params->{'album_id'} );
    my $loaded = $album->load( speculative => 1 );

    if ( $loaded == 0 || ref( $album ) ne 'Side7::UserContent::Album' )
    {
        flash error => 'The Album you tried to access either could not be found or does not exist.';
        return redirect '/my/albums';
    }

    if ( session( 'user_id' ) != $album->user_id() )
    {
        flash error => 'The Album you tried to access does not belong to your Account.';
        return redirect '/my/albums';
    }

    my $affected_user = Side7::User::get_user_by_id( $album->user_id() );

    my $audit_msg = 'Managing Album Contents - <b>Results</b>:<br>';
    $audit_msg   .= 'Album &gt;' . $album->name() . '&lt; ( Album ID: ' . $album->id() . ' )<br>';
    $audit_msg   .= 'belonging to User &gt;' . $affected_user->username() . '&lt; ( User ID: ' . $affected_user->id() . ' )<br>';

    my $flash_error = '';

    # Fulfill any Remove requests
    # As we go through each request, we will ensure that the content being operated on
    # actually belongs to the User.
    # TODO: Clean this up and make each of the following ifs into a class method.
    foreach my $content ( @$content_to_remove )
    {
        my ( $content_type, $content_id ) = split( /-/, $content );

        if ( $content_type eq 'music' )
        {
            # Music removal
            my $map = Side7::UserContent::AlbumMusicMap->new( album_id => $album->id(), music_id => $content_id );
            my $loaded = $map->load( speculative => 1 );

            if ( $loaded == 0 )
            {
                flash error => 'Could not find the Music being referenced for removal from this Album.';
                return redirect '/my/albums/' . $album->id() . '/manage';
            }

            my $deleted = $map->delete;
            if ( ! $deleted )
            {
                $LOGGER->warn( 'Could not remove Music ID >' . $content_id . '< from Album >' .
                                $album->name() . ' (ID: ' . $album->id() . ')<: ' . $map->error() );
                $audit_msg .= '<strong>Could not remove Music ID &gt;' . $content_id . '&lt; from Album: ' .
                                $map->error() . '</strong><br>';

                $flash_error .= 'Could not remove a Music item being referenced from this Album.<br>';
                return redirect '/my/albums/' . $album->id() . '/manage';
            }
            else
            {
                $audit_msg .= 'Removed Music ID &gt;' . $content_id . '&lt; from Album<br>';
            }
        }
        elsif ( $content_type eq 'literature' )
        {
            # TODO: set up literature rules
        }
        else
        {
            # Image removal
            my $map = Side7::UserContent::AlbumImageMap->new( album_id => $album->id(), image_id => $content_id );
            my $loaded = $map->load( speculative => 1 );

            if ( $loaded == 0 )
            {
                flash error => 'Could not find the Image being referenced for removal from this Album.';
                return redirect '/my/albums/' . $album->id() . '/manage';
            }

            my $deleted = $map->delete;
            if ( ! $deleted )
            {
                $LOGGER->warn( 'Could not remove Image ID >' . $content_id . '< from Album >' .
                                $album->name() . ' (ID: ' . $album->id() . ')<: ' . $map->error() );
                $audit_msg .= '<strong>Could not remove Image ID &gt;' . $content_id . '&lt; from Album: ' .
                                $map->error() . '</strong><br>';

                $flash_error .= 'Could not remove an Image being referenced from this Album.<br>';
                return redirect '/my/albums/' . $album->id() . '/manage';
            }
            else
            {
                $audit_msg .= 'Removed Image ID &gt;' . $content_id . '&lt; from Album<br>';
            }
        }
    }

    # Fulfill any Add requests
    # As we go through each request, we will ensure that the content being operated on
    # actually belongs to the User.
    # TODO: Clean this up and make each of the following ifs into a class method.
    foreach my $content ( @$content_to_add )
    {
        my ( $content_type, $content_id ) = split( /-/, $content );

        if ( $content_type eq 'music' )
        {
            # Music adding
            my $map = Side7::UserContent::AlbumMusicMap->new( album_id => $album->id(), music_id => $content_id, created_at => DateTime->now(), updated_at => DateTime->now() );
            my $saved = $map->save();

            if ( ! $saved )
            {
                $LOGGER->warn( 'Could not add Music ID >' . $content_id . '< to Album >' . $album->name() . ' (ID: ' . $album->id() . ')<: ' . $map->error() );
                $audit_msg .= '<strong>Could not add Music ID &gt;' . $content_id . '&lt; to Album: ' . $map->error() . '</strong><br>';

                $flash_error .= 'Could not add a Music item to this Album.<br>';
                return redirect '/my/albums/' . $album->id() . '/manage';
            }
            else
            {
                $audit_msg .= 'Added Music ID &gt;' . $content_id . '&lt; to Album<br>';
            }
        }
        elsif ( $content_type eq 'literature' )
        {
            # TODO: set up literature rules
        }
        else
        {
            # Image adding
            my $map = Side7::UserContent::AlbumImageMap->new( album_id => $album->id(), image_id => $content_id, created_at => DateTime->now(), updated_at => DateTime->now() );
            my $saved = $map->save();

            if ( ! $saved )
            {
                $LOGGER->warn( 'Could not add Image ID >' . $content_id . '< to Album >' . $album->name() . ' (ID: ' . $album->id() . ')<: ' . $map->error() );
                $audit_msg .= '<strong>Could not add Image ID &gt;' . $content_id . '&lt; to Album: ' . $map->error() . '</strong><br>';

                $flash_error .= 'Could not add an Image to this Album.<br>';
                return redirect '/my/albums/' . $album->id() . '/manage';
            }
            else
            {
                $audit_msg .= 'Added Image ID &gt;' . $content_id . '&lt; to Album<br>';
            }
        }
    }

    $album->updated_at( DateTime->now() );
    $album->save();

    my $remote_host = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_log = Side7::AuditLog->new(
                                          title          => 'User Album Contents Updated',
                                          description    => $audit_msg,
                                          ip_address     => request->address() . $remote_host,
                                          user_id        => session( 'user_id' ),
                                          affected_id    => params->{'album_id'},
                                          original_value => undef,
                                          new_value      => undef,
                                          timestamp      => DateTime->now(),
    );
    $audit_log->save();

    flash message => 'Content for <strong>' . $album->name() . '</strong> successfully updated!';
    return redirect '/my/albums/' . params->{'album_id'} . '/manage';
};

# User Preferences Settings Page
get '/my/preferences/?' => sub
{
    my $user = Side7::User::get_user_by_id( session( 'user_id' ) );
    my $user_preferences = Side7::User::Preference->new( user_id => session( 'user_id' ) );
    my $loaded = $user_preferences->load( speculative => 1 );

    if
    (
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
    if
    (
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

    template 'my/preferences', {
                                user_preferences => $user_preferences,
                                enums            => $enums,
                                is_adult         => $is_adult,
                                activity_log     => vars->{'activity_log'},
                               };
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
    my $audit_msg = 'User Preferences Updated - <b>Successful</b><br>' .
                    'Preferences for &gt;' . $affected_user->username() . '&lt; ( User ID: ' . params->{'user_id'} . ' )<br>' .
                    'updated by &gt;<b>' . session( 'username' ) . '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
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
    template 'my/preferences', { user_preferences => $new_preferences, enums => $enums, activity_log => vars->{'activity_log'} };
};

# User Gallery Landing Page
get '/my/gallery/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'my/gallery', { user => $user, activity_log => vars->{'activity_log'} };
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
                            upload_type   => params->{'upload_type'},
                            enums         => $enums,
                            categories    => $categories,
                            ratings       => $ratings,
                            qualifiers    => $qualifiers,
                            stages        => $stages,
                            activity_log  => vars->{'activity_log'},
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
                            filename          => params->{'filename'},
                            upload_type       => params->{'upload_type'},
                            overwrite_dupe    => params->{'overwrite_dupe'},
                            category_id       => params->{'category_id'},
                            rating_id         => params->{'rating_id'},
                            rating_qualifiers => params->{'rating_qualifiers'},
                            stage_id          => params->{'stage_id'},
                            title             => params->{'title'},
                            description       => params->{'description'},
                            transcript        => params->{'transcript'},
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
    my $upload_dir = $user->get_content_directory( params->{'upload_type'} );

    $LOGGER->debug( 'UPLOAD DIR: >' . $upload_dir . '<' );

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

    my $remote_host   = ( defined request->remote_host() ) ? ' - ' . request->remote_host() : '';
    my $audit_message = '';
    my $new_values    = '';

    my $new_content = undef;

    # Common Fields between upload types.
    my $copyright_year = undef;
    if ( defined params->{'copyright_year'} )
    {
        $copyright_year = DateTime->today->year();
    }

    my $now = DateTime->now();

    my $checksum = '';
    my $fh = new IO::File;
    if ( $fh->open( '< ' . $upload_dir . params->{'filename'} ) )
    {
        binmode ($fh);
        $checksum = Digest::MD5->new->addfile($fh)->hexdigest();
    }
    else
    {
        $LOGGER->warn( 'Could not generate MD5 hash of uploaded file: >' . $upload_dir . params->{'filename'} . '<' );
    }

    # Insert the content record into the database.
    # TODO: REFACTOR THIS CRAP.
    if ( lc( params->{'upload_type'} ) eq 'image' )
    {
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

        $new_content = Side7::UserContent::Image->new(
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
                                                        is_archived       => 0,
                                                        privacy           => params->{'privacy'},
                                                        checksum          => $checksum,
                                                        created_at        => $now,
                                                        updated_at        => $now,
                                                     );

        $new_content->save();

        $audit_message  = 'User &gt;<b>' . session( 'username' ) .
                          '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ) uploaded new Content:<br />';
        $audit_message .= 'Content Type: image<br />';
        $new_values     = 'Filename: &gt;' . params->{'filename'} . '&lt;<br />';
        $new_values    .= 'Filesize: &gt;' . $file->size() . '&lt;<br />';
        $new_values    .= 'Dimensions: &gt;' . $file_stats->{'dimensions'} . '&lt;<br />';
        $new_values    .= 'Category_id: &gt;' . params->{'category_id'} . '&lt;<br />';
        $new_values    .= 'Rating_id: &gt;' . params->{'rating_id'} . '&lt;<br />';
        $new_values    .= 'Rating_qualifiers: &gt;' . ( $rating_qualifiers // '' ) . '&lt;<br />';
        $new_values    .= 'Stage_id: &gt;' . params->{'stage_id'} . '&lt;<br />';
        $new_values    .= 'Title: &gt;' . params->{'title'} . '&lt;<br />';
        $new_values    .= 'Description: &gt;' . ( params->{'description'} // '' ) . '&lt;<br />';
        $new_values    .= 'Copyright_year: &gt;' . ( $copyright_year // '' ) . '&lt;<br />';
        $new_values    .= 'Privacy: &gt;' . params->{'privacy'} . '&lt;<br />';
        $new_values    .= 'Created_at: &gt;' . $now . '&lt;<br />';
        $new_values    .= 'Updated_at: &gt;' . $now . '&lt;<br />';
    }
    elsif ( lc( params->{'upload_type'} ) eq 'music' )
    {
        my $file_stats = Side7::Utils::Music->get_audio_stats( filepath => $upload_dir . $file->filename() );
        if ( defined $file_stats->{'error'} )
        {
            $LOGGER->warn( 'ERROR GETTING AUDIO STATS: ' . $file_stats->{'error'} );
            flash error => 'Invalid file format has been uploaded as an audio file.';
            return $return_to_form->();
        }

        $new_content = Side7::UserContent::Music->new(
                                                        user_id           => $user->id(),
                                                        filename          => params->{'filename'},
                                                        filesize          => $file_stats->{'filesize'},
                                                        category_id       => params->{'category_id'},
                                                        rating_id         => params->{'rating_id'},
                                                        stage_id          => params->{'stage_id'},
                                                        title             => params->{'title'},
                                                        description       => params->{'description'},
                                                        transcript        => params->{'transcript'},
                                                        encoding          => $file_stats->{'encoding'},
                                                        bitrate           => $file_stats->{'bitrate'},
                                                        sample_rate       => $file_stats->{'samplerate'},
                                                        length            => $file_stats->{'length'},
                                                        copyright_year    => $copyright_year,
                                                        is_archived       => 0,
                                                        privacy           => params->{'privacy'},
                                                        checksum          => $checksum,
                                                        created_at        => $now,
                                                        updated_at        => $now,
                                                     );

        $new_content->save();

        if ( defined params->{'artwork_filename'} )
        {
            my $upload_dir = $user->get_music_artwork_directory();

            $LOGGER->debug( 'UPLOAD DIR: >' . $upload_dir . '<' );

            # Upload the file
            my $file = request->upload( 'artwork_filename' );

            # Copy file to the User's directory
            $file->copy_to( $upload_dir . $file->filename() );

            $new_content->artwork_filename( params->{'artwork_filename'} );

            $new_content->save();
        }


        $audit_message  = 'User &gt;<b>' . session( 'username' ) .
                          '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ) uploaded new Content:<br />';
        $audit_message .= 'Content Type: music<br />';
        $new_values     = 'Filename: &gt;' . params->{'filename'} . '&lt;<br />';
        $new_values    .= 'Filesize: &gt;' . ( $file_stats->{'filesize'} // '' ) . '&lt;<br />';
        $new_values    .= 'Category_id: &gt;' . params->{'category_id'} . '&lt;<br />';
        $new_values    .= 'Rating_id: &gt;' . params->{'rating_id'} . '&lt;<br />';
        $new_values    .= 'Stage_id: &gt;' . params->{'stage_id'} . '&lt;<br />';
        $new_values    .= 'Title: &gt;' . params->{'title'} . '&lt;<br />';
        $new_values    .= 'Description: &gt;' . ( params->{'description'} // '' ) . '&lt;<br />';
        $new_values    .= 'Transcript: &gt;' . ( params->{'transcript'} // '' ) . '&lt;<br />';
        $new_values    .= 'Encoding: &gt;' . ( $file_stats->{'encoding'} // '' ) . '&lt;<br />';
        $new_values    .= 'Bitrate: &gt;' . ( $file_stats->{'bitrate'} // '' ) . '&lt;<br />';
        $new_values    .= 'Sample Rate: &gt;' . ( $file_stats->{'samplerate'} // '' ) . '&lt;<br />';
        $new_values    .= 'Length: &gt;' . ( $file_stats->{'length'} // '' ) . '&lt;<br />';
        $new_values    .= 'Copyright_year: &gt;' . ( $copyright_year // '' ) . '&lt;<br />';
        $new_values    .= 'Privacy: &gt;' . params->{'privacy'} . '&lt;<br />';
        $new_values    .= 'Artwork: &gt;' . params->{'artwork_filename'} . '&lt;<br />';
        $new_values    .= 'Created_at: &gt;' . $now . '&lt;<br />';
        $new_values    .= 'Updated_at: &gt;' . $now . '&lt;<br />';
    }
    elsif ( lc( params->{'upload_type'} ) eq 'literature' )
    {
        # TODO: Create Literature object. Make sure to use the $new_content object.
    }
    else
    {
        my $err_message = 'Could not add your upload to the database as we could not determine what kind of content it was.' .
                          ' We have made note of this error and will look into it.';

        flash error => $err_message;
        return $return_to_form->();
    }

    my $audit_log = Side7::AuditLog->new(
                                          user_id     => session( 'user_id' ),
                                          title       => 'New User Content Uploaded',
                                          description => $audit_message,
                                          ip_address  => request->address() . $remote_host,
                                          new_value   => $new_values,
                                          timestamp   => DateTime->now(),
    );

    $audit_log->save();

    my $activity_log = Side7::ActivityLog->new(
                                                user_id    => session( 'user_id' ),
                                                activity   => '<a href="/user/' . session( 'username' ) . '">' . session( 'username' ) .
                                                              '</a> posted new <a href="/' . lc( params->{'upload_type'} ) . '/' . $new_content->id .
                                                              '">' . lc( params->{'upload_type'} ) . ' content</a>.',
                                                created_at => DateTime->now(),
    );
    $activity_log->save();

    flash message => 'Hooray! Your file <b>' . $file->filename() . '</b> has been uploaded successfully.';
    redirect '/my/gallery';
};

# User Permissions Explanation Page ( Might be temporary )
get '/my/permissions/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    my $permissions = $user->get_all_permissions();
    my $user_hash = {};

    template 'my/permissions', { user => $user_hash, permissions => $permissions, activity_log => vars->{'activity_log'} };
};

# User Perks Landing Page ( Might be temporary )
get '/my/perks/?' => sub
{
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    my $perks = $user->get_all_perks();
    my $user_hash = {};

    template 'my/perks', { user => $user_hash, perks => $perks, activity_log => vars->{'activity_log'} };
};

# User Private Messages
## PM Listing View
get qr{/my/pms/?(\d*)/?} => sub
{
    my ( $page ) = splat;
    $page //= 1;
    my $user = Side7::User::get_user_by_username( session( 'username' ) );

    my $private_messages = Side7::PrivateMessage::Manager->get_private_messages( query => [
                                                                                            recipient_id => $user->id,
                                                                                            '!status'    => 'Deleted',
                                                                                          ],
                                                                                 sort_by  => 'created_at desc',
                                                                                 per_page => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
                                                                                 page     => $page,
                                                                                 #with_objects => [ 'sender.account' ],
    );

    template 'my/pms', {
                        user => $user,
                        pms  => $private_messages,
                        page => $page,
                        activity_log => vars->{'activity_log'},
                       };
};

## PM Composition View
get '/my/pms/compose/?' => sub
{
    template 'my/compose_private_message', {}, { layout => 'my_lightbox' };
};

# PM Send Action
post '/my/pms/send/?' => sub
{
    my $params    = params;
    my $recipient = params->{'recipient'};
    my $subject   = params->{'subject'};
    my $body      = params->{'body'};
    my $reply_to  = params->{'reply_to'};

    my $data = validator( $params, 'private_message_send_form.pl' );

    # Return to Compose if errors.
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

        return template 'my/compose_private_message', {
                                                        recipient => $recipient,
                                                        subject   => $subject,
                                                        body      => $body,
                                                        reply_to  => $reply_to,
                                                      },
                                                      { layout => 'my_lightbox' };
    }

    my $sent_message = Side7::PrivateMessage->new(
                                                    recipient_id => Side7::User::get_user_by_username( $recipient )->id,
                                                    sender_id    => session( 'user_id' ),
                                                    subject      => $subject,
                                                    body         => $body,
                                                    status       => 'Delivered',
                                                    created_at   => DateTime->now(),
    );
    $sent_message->save;

    if ( defined $reply_to && $reply_to =~ m/^\d+$/ )
    {
        my $private_message = Side7::PrivateMessage->new( id => $reply_to );
        my $loaded = $private_message->load( speculative => 1 );

        if ( $loaded != 0 && ref( $private_message ) eq 'Side7::PrivateMessage' )
        {
            $private_message->status( 'Replied To' );
            $private_message->replied_at( DateTime->now );
            $private_message->save;
        }
    }

    template 'my/private_message_sent', { recipient => $recipient }, { layout => 'my_lightbox' };
};

## PM Read View
get '/my/pms/message/:pm_id/?' => sub
{
    my $pm_id = params->{'pm_id'} // undef;

    if ( ! defined $pm_id || $pm_id !~ /^\d+$/ )
    {
        return template 'my/private_message_error', { error => 'Sorry, could not retrieve the requested message.' },
                                                    { layout => 'my_lightbox' };
    }

    my $private_message = Side7::PrivateMessage->new( id => $pm_id );
    my $loaded = $private_message->load( speculative => 1 );

    if ( $loaded == 0 || ref( $private_message ) ne 'Side7::PrivateMessage' )
    {
        return template 'my/private_message_error', { error => 'Sorry, could not retrieve the requested message.' },
                                                    { layout => 'my_lightbox' };
    }

    if ( session( 'user_id' ) ne $private_message->recipient_id )
    {
        return template 'my/private_message_error', { error => 'It appears you are trying to read messages that are not yours.' },
                                                    { layout => 'my_lightbox' };
    }

    if ( $private_message->status eq 'Deleted' )
    {
        return template 'my/private_message_error', { error => 'Could not load the requested message: it has been deleted.' },
                                                    { layout => 'my_lightbox' };
    }

    if ( ! defined $private_message->read_at || $private_message->status eq 'Delivered' )
    {
        $private_message->status( 'Read' );
        $private_message->read_at( DateTime->now() );
        $private_message->save();
    }

    template 'my/read_private_message', { data => $private_message }, { layout => 'my_lightbox' };
};

## PM Reply View
get '/my/pms/message/:pm_id/reply/?' => sub
{
    my $pm_id = params->{'pm_id'} // undef;

    if ( ! defined $pm_id || $pm_id !~ /^\d+$/ )
    {
        return template 'my/private_message_error', { error => 'Sorry, could not retrieve the requested message.' },
                                                    { layout => 'my_lightbox' };
    }

    my $private_message = Side7::PrivateMessage->new( id => $pm_id );
    my $loaded = $private_message->load( speculative => 1, with => [ 'sender.account' ] );

    if ( $loaded == 0 || ref( $private_message ) ne 'Side7::PrivateMessage' )
    {
        return template 'my/private_message_error', { error => 'Sorry, could not retrieve the requested message.' },
                                                    { layout => 'my_lightbox' };
    }

    if ( session( 'user_id' ) ne $private_message->recipient_id )
    {
        return template 'my/private_message_error', { error => 'It appears you are trying to read messages that are not yours.' },
                                                    { layout => 'my_lightbox' };
    }

    my $quote = '[quote="' . $private_message->sender->username . ' wrote on ' .
                $private_message->created_at->strftime( '%a, %d %b, %Y at %H:%M' ) .
                '"]' . $private_message->body . '[/quote]';

    template 'my/compose_private_message', {
                                            recipient => $private_message->sender->username,
                                            reply_to  => $private_message->id,
                                            quote     => $quote,
                                            subject   => (
                                                            ( $private_message->subject !~ m/^RE:\s/ ) ? 'RE: ' . $private_message->subject
                                                                                                       : $private_message->subject
                                                         ),
                                           }, { layout => 'my_lightbox' };
};

## PM Delete View

## PM Delete Action
get '/my/pms/message/:pm_id/delete/?' => sub
{
    my $pm_id = params->{'pm_id'} // undef;

    if ( ! defined $pm_id || $pm_id !~ /^\d+$/ )
    {
        return template 'my/private_message_error', { error => 'Sorry, could not retrieve the requested message.' },
                                                    { layout => 'my_lightbox' };
    }

    my $private_message = Side7::PrivateMessage->new( id => $pm_id );
    my $loaded = $private_message->load( speculative => 1, with => [ 'sender.account' ] );

    if ( $loaded == 0 || ref( $private_message ) ne 'Side7::PrivateMessage' )
    {
        return template 'my/private_message_error', { error => 'Sorry, could not retrieve the requested message.' },
                                                    { layout => 'my_lightbox' };
    }

    if ( session( 'user_id' ) ne $private_message->recipient_id )
    {
        return template 'my/private_message_error', { error => 'It appears you are trying to read messages that are not yours.' },
                                                    { layout => 'my_lightbox' };
    }

    $private_message->status( 'Deleted' );
    $private_message->deleted_at( DateTime->now() );
    $private_message->save;

    template 'my/private_message_deleted', { pm => $private_message }, { layout => 'my_lightbox' };
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
#use Dancer::Plugin::NYTProf;

use DateTime;
use List::Util;
use File::Path;
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
use Side7::Admin::Maintenance;
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
                my $error = 'User &gt;<b>' . session( 'username' ) .
                                '</b>&lt; attempted but is not authorized to view >' . request->path_info . '<';
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

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user_details', {
                                        user => $user,
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

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/user_edit_form', {
                                        user        => $user,
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

        my $sexes        = Side7::Admin::Dashboard::get_user_sexes_for_select();
        my $visibilities = Side7::Admin::Dashboard::get_birthday_visibilities_for_select();
        my $countries    = Side7::Admin::Dashboard::get_countries_for_select();

        my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

        return template 'admin/user_edit_form', {
                                            user        => $user,
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
        my $audit_msg = 'User Account Updated - <b>Successful</b><br>' .
                        'Account for &gt;' . $username . '&lt; ( User ID: ' . params->{'user_id'} . ' )' .
                        ' updated by &gt;</b>' . session( 'username' ) . '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
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

# User Private Messages
get '/users/:username/pms/?:msg_type?/?' => sub
{
    my $username = params->{'username'} // undef;
    my $msg_type = params->{'msg_type'} // 'sent';

    my $user = Side7::User::get_user_by_username( $username );

    my $pms = $user->get_private_messages( $msg_type );

    template 'admin/user_pms', {
                                user     => $user,
                                msg_type => $msg_type,
                                pms      => $pms,
                               }, { layout => 'admin_lightbox' };
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

    my $pagination = Side7::Utils::Pagination::get_pagination( { total_count => $news_count, page => $page } );

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );
    my $priorities = Side7::News->get_priority_names();

    template 'admin/news', {
                                        data          => {
                                                            news       => $results,
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

    my $priorities = Side7::News->get_priority_names();

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/news_details', {
                                        news        => $news,
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

    my $priorities = Side7::News->get_priority_names();

    my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

    template 'admin/news_edit_form', {
                                        news        => $news,
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

        my $priorities = Side7::News->get_priority_names();

        my $admin_user = Side7::User::get_user_by_username( session( 'username' ) );

        return template 'admin/news_edit_form', {
                                                    news_id     => $news_id,
                                                    news        => $news,
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
        my $audit_msg = 'News Item Updated - <b>Successful</b><br>' .
                        'Item &gt;' . $orig_news->title() . '&lt; ( News ID: ' . $news_id . ' )<br>' .
                        'updated by &gt;<b>' . session( 'username' ) . '</b>&lt; ( User ID: ' . session( 'user_id' ) . ' ).<br>';
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

# Admin Tools
get '/tools' => sub
{
    my $admin_user = Side7::User::get_user_by_id( session( 'user_id' ) );

    if ( ! $admin_user->is_role( [ qw/ Admin Owner / ] ) )
    {
        $LOGGER->warn( 'User >' . session( 'username' ) . '< attempted to access Admin Tools illegally.' );
        flash error => 'Access Denied';
        return redirect '/admin';
    }

    # Set Maintanance Mode Flag
    my $maint_file = $CONFIG->{'app_dir'} . '/maint_mode';
    my $maintenance_mode = ( -f $maint_file ) ? 1 : undef;

    my $menu_options = Side7::Admin::Dashboard::get_main_menu( username => session( 'username' ) );

    template 'admin/admin_tools.tt', {
                                        maintenance_mode => $maintenance_mode,
                                        main_menu        => $menu_options,
                                        permissions      => {
                                                            },
                                     },
                                     { layout => 'admin' };
};

get '/flush_tools/:flush_type/?' => sub
{
    my $admin_user = Side7::User::get_user_by_id( session( 'user_id' ) );

    if ( ! $admin_user->is_role( [ qw/ Admin Owner / ] ) )
    {
        $LOGGER->warn( 'User >' . session( 'username' ) . '< attempted to access Cache Flush Tools illegally.' );
        flash error => 'Access Denied';
        return redirect '/admin';
    }

    my $flush_type = params->{'flush_type'} // undef;

    if ( List::Util::none { $flush_type eq $_ } ( qw/ images avatars templates routes user_cache all / ) )
    {
        $LOGGER->warn( 'Invalid flush type >' . $flush_type . '< specified in Cache Flush.' );
        flash error => 'No clue what you are trying to flush.';
        return redirect '/admin/tools';
    }

    if ( List::Util::any { $flush_type eq $_ } ( qw/ images avatars templates / ) )
    {
        my $results = Side7::Admin::Maintenance->flush_cached_files( $flush_type );

        if ( ! $results->{'success'} )
        {
            flash error => '<strong>An error occurred while flushing cache:</strong> ' . $results->{'error'} . '<br>' .
                                $results->{'num_removed'} . ' files removed.';
            return redirect '/admin/tools';
        }

        flash message => 'The ' . ucfirst( $flush_type ) . ' cache has been flushed.<br>' . $results->{'num_removed'} . ' files removed.';
        return redirect '/admin/tools';
    }
};

true;
