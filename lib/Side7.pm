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
use Side7::UserContent::RatingQualifier;
use Side7::Utils::Crypt;
use Side7::Utils::Pagination;
use Side7::Utils::Image;
use Side7::FAQCategory;
use Side7::FAQCategory::Manager;
use Side7::FAQEntry;

our $VERSION = '0.1';

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
        $visitor = Side7::User->new( id => session( 'user_id' ) )->load( speculative => 1, with => 'user_preferences' );
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

        $LOGGER->debug( 'CATEGORY: ' . Dumper( $category ) );

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

    my ( $users, $user_count ) = Side7::User::get_users_for_directory( initial => $initial, page => $page, session => session );

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

post '/my/upload' => sub
{
    my $params = params;

    $LOGGER->debug( 'RATING_QUALIFIERS: ' . Dumper( params->{'rating_qualifiers'} ) );

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
            $rating_qualifiers = join( '', @{ params->{'rating_qualifiers'} } );
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
