#!/usr/bin/env perl

use strict;
use warnings;

use v5.18;
use lib '/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Side7::Globals;
use Side7::DB;
use Side7::User;
use Side7::User::Country;
use Side7::User::Role;
use Side7::User::Preference;
use Side7::Account;
use Side7::UserContent::Image;
use Side7::UserContent::Image::DailyView;
use Side7::UserContent::Image::Property;
use Side7::UserContent::CommentThread;
use Side7::UserContent::Comment;
use Side7::KudosCoin;
use Side7::Utils::Text;

use Getopt::Std;
use Carp;
use Data::Dumper;
use DBI();
use Time::HiRes qw( gettimeofday tv_interval );
use DateTime;

use vars qw(
    $VERSION %opt $has_opts $DB4 $DB5
);

$|++; 

$VERSION = 1.30;

init();

my $start;

if ( $opt{t} )
{
    $start = [ gettimeofday() ];
}

migrate();

if ( $opt{t} )
{
    my $elapsed = tv_interval( $start, [ gettimeofday() ] );
    say time_elapsed($elapsed);
}

exit 0;

sub init
{
    # VALID OPTIONS = 'vHDVetL'
    # [v]ersion, [H]elp, [D]ry-run, [V]erbose, [e]nvironment, [t]ime execution, [L]arge tables
    Getopt::Std::getopts( 'vHtDVe:L', \%opt ) or HELP_MESSAGE();

    HELP_MESSAGE()    if defined $opt{H};
    VERSION_MESSAGE() if defined $opt{v};

    # Are any options set?
    $has_opts = 0;
    foreach my $key( qw( v H D V t e L ) )
    {
        if ( defined $opt{$key} )
        {
            $has_opts = 1;
            last;
        }
    }
}

sub migrate
{
    say "Side 7 v5 Migration Script";
    say "==========================";
    say "Copyright (C) 2013-2014 Side 7";
    say '';
    say 'This is a dry run. Nothing will be written to DB5.' if defined $opt{D};
    say '';

    sleep (3); # Dramatic pause

    db_connect();
    migrate_users();
    migrate_user_preferences();
    migrate_account_credits();
    migrate_images();
    migrate_image_views();
    migrate_image_properties();
    migrate_image_comments();
    migrate_image_comment_threads();
    db_disconnect();
}

sub db_connect
{
    # Connect to the databases
    my $environment = 'development';
    if ( defined $opt{e} && lc($opt{e}) eq 'prod' )
    {
        $environment = 'production';
    }

    if ( defined $opt{V} ) { say "I am attempting to connect to v5 >$environment< DB."; }

    $DB5 = Side7::DB->new( domain => $environment ) || croak 'Could not connect to new DB';

    my $v4_db   = 'side7_v4';
    my $v4_host = 'localhost';
    my $v4_un   = 's7old';
    my $v4_pw   = 's7CPR';

    $DB4 = DBI->connect( "DBI:mysql:database=$v4_db;host=$v4_host", $v4_un, $v4_pw ) 
        || croak 'Could not connect to old DB';

    if ( defined $opt{V} ) { say 'Connected to both the v4 and v5 databases.'; }
}

sub db_disconnect
{
    $DB4->disconnect() || croak 'Could not disconnect from v4 database.';

    if ( defined $opt{V} ) { say 'Disconnected to both the v4 and v5 databases.'; }
}

sub migrate_users
{
    if ( defined $opt{V} ) { say "=> Migrating Users."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 User and Account tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ accounts users / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 user_accounts table;
    if ( defined $opt{V} ) { say "\t=> Pulling user accounts from v4 DB."; }

    my $sth = $DB4->prepare(
       'SELECT ua.*, ua.id as user_id, uap.*, uas.*
        FROM user_accounts ua 
        INNER JOIN user_account_personal_info uap
            ON uap.user_account_id = ua.id
        INNER JOIN user_account_system_info uas
            ON uas.user_account_id = ua.id
        ORDER BY ua.id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my %statuses = (
        Pending   => 1,
        Active    => 2,
        Suspended => 3,
        Disabled  => 4,
    );

    my %types = (
        1 => 1, # Visitor -> Basic
        2 => 1, # 1 Star  -> Basic
        3 => 2, # 3 Star  -> Premiere
        4 => 3, # 5 Star  -> Subscriber
    );

    my %user_roles = (
        1 => 2, # Visitor -> Basic
        2 => 2, # 1 Star  -> Basic
        3 => 2, # 3 Star  -> Basic
        4 => 3, # 5 Star  -> Subscriber
    );

    my %datevis = (
        'Full'    => 1,
        'No Year' => 2,
        'Hidden'  => 3,
    );

    my $user_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        my $user = Side7::User->new(
            id            => $row->{user_id},
            username      => $row->{username},
            password      => $row->{password},
            email_address => $row->{email_address},
            created_at    => $row->{join_date},
            updated_at    => $row->{modified_date},
        );
        $user->save if ! defined $opt{D};

        # Various cleanup tasks
        my $country_id = 228;
        my $country = ( defined $row->{country} ) ?
            Side7::User::Country->new( name => substr($row->{country},0,45) )->load( speculative => 1 ) :
            0;
        if ( ref $country eq 'Side7::User::Country' )
        {
            $country_id = $country->{id};
        }

        my $birthday = '0000-00-00';
        if (
            defined $row->{birthdate}
            && 
            $row->{birthdate} ne '0000-00-00'
            &&
            $row->{birthdate} !~ m/0{2,4}/)
        {
            $birthday = $row->{birthdate};
        }

        my $expire_on;
        if ( defined $row->{tier_3_expiration_date} )
        {
            $expire_on = $row->{tier_3_expiration_date};
        }
        elsif ( defined $row->{tier_2_expiration_date} )
        {
            $expire_on = $row->{tier_2_expiration_date};
        }

        my $is_public_hash = _get_is_public_hash( number => $row->{is_public} );
        my $is_public;

        # IS_PUBLIC IS A PACKED FIELD:
        # Old values:
        # @titles = ( 'email', 'icq', 'aim', 'msn', 'yahoo', 'googletalk', 'state', 'country' );
        # New values:
        my @titles = ( 'email', 'aim', 'yahoo', 'gtalk', 'skype', 'state', 'country' );
        if ( defined $is_public_hash && ref( $is_public_hash ) eq 'HASH' )
        {
            foreach my $key ( @titles )
            {
                my $value = ( $key eq 'gtalk' ) ? $is_public_hash->{'googletalk'} : $is_public_hash->{$key};
                $is_public .= "$key:". ( $value // 0 ) . ';';
            }
        }

        my $account = Side7::Account->new(
            user_id                 => $row->{user_id},
            first_name              => $row->{first_name},
            last_name               => $row->{last_name},
            user_type_id            => $types{$row->{access_control_list_id}},
            user_status_id          => $statuses{$row->{status}},
            user_role_id            => $user_roles{$row->{access_control_list_id}},
            other_aliases           => $row->{alias},
            biography               => $row->{biography},
            sex                     => $row->{sex},
            birthday                => $birthday,
            birthday_visibility     => $datevis{$row->{birthdate_mode}},
            webpage_name            => $row->{webpage_name},
            webpage_url             => $row->{webpage_url},
            blog_name               => $row->{journal_name},
            blog_url                => $row->{journal_url},
            aim                     => $row->{aim},
            yahoo                   => $row->{yahoo},
            gtalk                   => $row->{googletalk},
            state                   => $row->{state},
            country_id              => $country_id,
            is_public               => $is_public,
            referred_by             => $row->{referred_by},
            subscription_expires_on => $expire_on,
            created_at              => $row->{join_date},
            updated_at              => $row->{modified_date},
        );
        $account->save if ! defined $opt{D};

        $user_count++;
        print _progress_dot( total => $row_count, count => $user_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated users & accounts: " . _commafy( $user_count ) if defined $opt{V};
}

sub migrate_user_preferences
{
    if ( defined $opt{V} ) { say "=> Migrating User Preferences."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 User Preferences tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ user_preferences / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 user_preferences table;
    if ( defined $opt{V} ) { say "\t=> Pulling user preferences from v4 DB."; }

    my $sth = $DB4->prepare(
       'SELECT up.*, up.id as user_preference_id
        FROM user_preferences up 
        ORDER BY up.id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $pref_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {

        # Minor cleanup
        my $show_m_thumbs = ( $row->{display_show_rated_m_thumbnails} eq 'Nowhere' ) ? 0 : 1;
        my $display_type  = ( $row->{display_image_list_type} eq 'Thumbnails' )      ? 'Grid' : 'List';
        my $comment_type  = ( $row->{account_default_comment_type_setting} eq 'Any Kind' ) ? 'Any' 
                                : $row->{account_default_comment_type_setting};
        my $comment_visibility = ( $row->{account_default_comment_visibility_setting} eq 'Hide All' ) ? 'Hide' : 'Show';

        my $pref = Side7::User::Preference->new(
            id                         => $row->{user_preference_id},
            user_id                    => $row->{user_account_id},
            display_signature          => Side7::Utils::Text::true_false_to_int( $row->{account_display_signature} ),
            show_management_thumbs     => Side7::Utils::Text::true_false_to_int( $row->{account_show_management_thumbnails} ),
            default_comment_visibility => $comment_visibility,
            default_comment_type       => $comment_type,
            allow_watching             => Side7::Utils::Text::true_false_to_int( $row->{privacy_prevent_museum_additions} ),
            allow_favoriting           => Side7::Utils::Text::true_false_to_int( $row->{privacy_prevent_image_favorites} ),
            allow_sharing              => 1,
            allow_email_through_forms  => Side7::Utils::Text::true_false_to_int( $row->{privacy_allow_email_through_forms} ),
            allow_pms                  => Side7::Utils::Text::true_false_to_int( $row->{privacy_allow_pms} ),
            pms_notifications          => Side7::Utils::Text::true_false_to_int( $row->{privacy_notify_of_pms} ),
            comment_notifications      => Side7::Utils::Text::true_false_to_int( $row->{privacy_notify_of_comments} ),
            show_online                => Side7::Utils::Text::true_false_to_int( $row->{privacy_show_online} ),
            thumbnail_size             => $row->{display_thumbnail_size},
            content_display_type       => $display_type,
            show_m_thumbs              => $show_m_thumbs,
            show_adult_content         => 0,
            display_full_sized_images  => $row->{display_full_sized_images},
            created_at                 => 'now()',
            updated_at                 => 'now()',
        );
        $pref->save if ! defined $opt{D};

        $pref_count++;
        print _progress_dot( total => $row_count, count => $pref_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated users preferences: " . _commafy( $pref_count ) if defined $opt{V};
}

sub migrate_images
{
    if ( defined $opt{V} ) { say "=> Migrating Images."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Image tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ images / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 user_accounts table;
    if ( defined $opt{V} ) { say "\t=> Pulling image records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT *, id as image_id
         FROM images
         ORDER BY images.id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $image_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.
        my $privacy = 'Public';

        if ( uc( $row->{friends_only} ) eq 'TRUE' )
        {
            $privacy = 'Friends Only';
        }

        my $archived = ( uc( $row->{is_archived} ) eq 'TRUE' ) ? 1 : 0;

        my %rating_qualifiers = (
            1 => 'D',
            2 => 'L',
            3 => 'N',
            4 => 'S',
            5 => 'V',
            6 => 'O',
        );

        my $qualifiers;
        if ( defined $row->{image_rating_qualifiers} && $row->{image_rating_qualifiers} !~ m/^\s*$/ )
        {
            $row->{image_rating_qualifiers} =~ s/\s+//g;
            foreach my $key ( split( /,|/, $row->{image_rating_qualifiers} ) )
            {
                $qualifiers .= $rating_qualifiers{$key};
            }
        }

        # Create image and save it.
        my $image = Side7::UserContent::Image->new(
            id                => $row->{image_id},
            user_id           => $row->{user_account_id},
            filename          => $row->{filename},
            title             => $row->{title},
            filesize          => $row->{filesize},
            dimensions        => $row->{dimensions},
            category_id       => $row->{image_category_id},
            rating_id         => $row->{image_rating_id},
            rating_qualifiers => ( $qualifiers // undef ),
            stage_id          => $row->{image_class_id},
            description       => $row->{description},
            privacy           => $privacy,
            is_archived       => $archived,
            copyright_year    => $row->{copyright_year},
            created_at        => $row->{uploaded_date},
            updated_at        => $row->{last_modified_date},
        );
        $image->save if ! defined $opt{D};

        $image_count++;

        print _progress_dot( total => $row_count, count => $image_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated images: " . _commafy( $image_count ) if defined $opt{V};
}

sub migrate_image_views
{
    if ( defined $opt{V} ) { say "=> Migrating Image Views."; }

    if ( ! defined $opt{L} )
    {
        say "\t=> Skipping large table migration.";
        return;
    }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Image View tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ image_daily_views image_detailed_views / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 user_accounts table;
    if ( defined $opt{V} ) { say "\t=> Pulling image views records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT *, id as image_view_id
         FROM image_views
         ORDER BY image_views.id'
    ) || croak "\t=> Could not prepare DB4 SQL statement.\n";
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $image_view_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create image and save it.
        my $image_view = Side7::UserContent::Image::DailyView->new(
            id                => $row->{image_view_id},
            image_id          => $row->{image_id},
            views             => $row->{count},
            date              => $row->{date},
        );
        $image_view->save if ! defined $opt{D};

        $image_view_count++;
        print _progress_dot( total => $row_count, count => $image_view_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated image views: " . _commafy( $image_view_count ) if defined $opt{V};
}

sub migrate_image_properties
{
    if ( defined $opt{V} ) { say "=> Migrating Image Properties."; }

    if ( ! defined $opt{L} ) 
    { 
        say "\t=> Skipping large table migration.";
        return;
    }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Image Properties tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ image_properties / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 image_descriptions table;
    if ( defined $opt{V} ) { say "\t=> Pulling image description records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT *, id as image_description_id
         FROM image_descriptions
         ORDER BY image_descriptions.id'
    ) || croak "\t=> Could not prepare DB4 SQL statement.\n";
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $image_property_count = 0;

    my $datetime = DateTime->today();

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.
        my %fields = (
            additional_credits           => 'Additional Credits',
            reference_source             => 'Reference Source',
            for_sale                     => 'For Sale',
            for_sale_contact_type        => 'Sale Contact Method',
            for_sale_contact_information => 'Sale Contact Information',
            allow_favoriting             => 'Allow Favoriting',
            allow_bookmarking            => 'Allow Sharing',
            allow_comments               => 'Allow Comments',
            allow_anonymous_comments     => 'Allow Anonymous Comments',
            show_comments                => 'Display Comments',
            comment_type_desired         => 'Perfered Comment Type',
        );

        foreach my $key ( keys %fields )
        {
            next if ! defined $row->{$key} || $row->{$key} eq '';

            # Create image property and save it.
            my $image_property = Side7::UserContent::Image::Property->new(
                image_id          => $row->{image_id},
                name              => $fields{$key},
                value             => $row->{$key},
                created_at        => $datetime->ymd(),
                updated_at        => $datetime->ymd(),
            );
            $image_property->save if ! defined $opt{D};

            $image_property_count++;
            print _progress_dot( total => $row_count, count => $image_property_count, interval => $interval ) if defined $opt{V};
        }
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated image properties: " . _commafy( $image_property_count ) if defined $opt{V};
}

sub migrate_image_comments
{
    if ( defined $opt{V} ) { say "=> Migrating Image Comments."; }

#    if ( ! defined $opt{L} ) 
#    { 
#        say "\t=> Skipping large table migration.";
#        return;
#    }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Image Comments tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ comments / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 image_descriptions table;
    if ( defined $opt{V} ) { say "\t=> Pulling image comment records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT *, id as image_comment_id
         FROM image_comments
         ORDER BY image_comments.id'
    ) || croak "\t=> Could not prepare DB4 SQL statement.\n";
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $image_comment_count = 0;

    my $datetime = DateTime->today();

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create image property and save it.
        my $comment = Side7::UserContent::Comment->new(
            id                => $row->{image_comment_id},
            comment_thread_id => $row->{image_comment_thread_id},
            user_id           => $row->{user_account_id},
            anonymous_name    => $row->{anonymous_name},
            comment           => $row->{comment},
            private           => ( $row->{private} eq 'true' ) ? 1 : 0,
            award             => ( defined $row->{rating} && $row->{rating} ne '' ) ? $row->{rating} : 'none',
            owner_rating      => '',
            ip_address        => $row->{ip_address},
            created_at        => $row->{'timestamp'},
            updated_at        => $datetime->ymd(),
        );
        $comment->save if ! defined $opt{D};

        $image_comment_count++;
        print _progress_dot( total => $row_count, count => $image_comment_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated image comments: " . _commafy( $image_comment_count ) if defined $opt{V};
}

sub migrate_image_comment_threads
{
    if ( defined $opt{V} ) { say "=> Migrating Image Comment Threads."; }

#    if ( ! defined $opt{L} ) 
#    { 
#        say "\t=> Skipping large table migration.";
#        return;
#    }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Image Comment Threads tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ comment_threads / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 image_descriptions table;
    if ( defined $opt{V} ) { say "\t=> Pulling image comment thread records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT *, id as image_comment_thread_id
         FROM image_comment_threads
         ORDER BY image_comment_threads.id'
    ) || croak "\t=> Could not prepare DB4 SQL statement.\n";
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $image_thread_count = 0;

    my $datetime = DateTime->today();

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create image property and save it.
        my $comment_thread = Side7::UserContent::CommentThread->new(
            id            => $row->{'image_comment_thread_id'},
            content_id    => $row->{image_id},
            content_type  => 'image',
            thread_status => 'open',
            created_at    => $row->{'timestamp'},
            updated_at    => $datetime->ymd(),
        );
        $comment_thread->save if ! defined $opt{D};

        $image_thread_count++;
        print _progress_dot( total => $row_count, count => $image_thread_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated image comment threads: " . _commafy( $image_thread_count ) if defined $opt{V};
}

sub time_elapsed
{
    my $elapsed = shift;
    my $time = sprintf("%02d:%02d:%02d", (gmtime($elapsed))[2,1,0]);

    return "Elapsed migration time: $time";
}

sub HELP_MESSAGE
{
    say "usage: $0 [-vHDVtL] [-e <environment>]";
    say '-v             Reports the script version.';
    say '-H             Displays this help message.';
    say '-D             Runs in dry-run mode, saving no data to the database.';
    say '-V             Runs in verbose mode.';
    say '-e <environ>   Establishes which environment to run the script; defaults to \'development\'';
    say '-t             Reports elapsed execution time';
    say '-L             Includes large tables in the migration (>500k rows).';
    exit 0;
}

sub VERSION_MESSAGE
{
    say "$0 version $VERSION";
    exit 0;
}

# PRIVATE FUNCTIONS

# This function comes from the v4 Library_side7.pm
sub _get_is_public_hash
{
    my ( %params ) = @_;
    my ( %is_public, $binary, @values, $value, @titles, $i );

    $params{'number'}    ||= 0;
    $params{'truefalse'} ||= 0;

    # SET UP THE VARIABLE TITLES
    @titles = ( 'email', 'icq', 'aim', 'msn', 'yahoo', 'googletalk', 'state', 'country' );

    # IS_PUBLIC CONTAINS:  email, icq, aim, msn, yahoo, googletalk, state, country
    $binary = _decimal_to_binary( number => $params{'number'} );

    return undef if ! defined $binary;

    # SPLIT THE BINARY NUMBER INTO DIGITS, AND PUT INTO AN ARRAY FOR SORTING
    @values = split( //, $binary );

    # REVERSE THE VALUES INTO THE PROPER ORDER
    @values = reverse @values;

    # PUSH THE VALUES INTO A HASH
    $i = 0;
    foreach $value ( @values ) {
        if ( $params{'truefalse'} > 0 ) {
            $value = _int_to_true_false( text => int( $value ) );
        }

        # BUILD THE HASH
        $is_public{$titles[$i]} = $value;

        $i++;
    }

    return ( \%is_public );
}

# This function comes from the v4 Library_global.pm
sub _decimal_to_binary
{
    my ( %params ) = @_;
    my ( $binary );

    $params{'number'} || return undef;

    $binary = sprintf( "%b", $params{'number'} );

    return( $binary );
}

# This function comes from the v4 Library_global.pm
sub _int_to_true_false
{
    my ( %params ) = @_;

    if ( int( $params{'text'} ) == 1 )
    {
        return( 'true' );
    } else {
        return( 'false' );
    }
}

sub _commafy
{
    my ( $text ) = @_;

    my $rev_text = reverse $text;

    $rev_text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g; # Comma is here. Change to period for Europe.

    return scalar reverse $rev_text;
}

sub _progress_dot
{
    my ( %args ) = @_;

    my $total    = delete $args{'total'};
    my $count    = delete $args{'count'};
    my $interval = delete $args{'interval'};

    return if ! defined $total || ! defined $count;

    if (
        defined $interval
        &&
        $count % $interval == 0
    )
    {
        return ( $count > $total ) ? '+ ' : '. ';
    }
    elsif (
        ! defined $interval
        &&
        $total % $count == 0 )
    {
        return '. ';
    }

    return;
}

sub migrate_account_credits
{
    if ( defined $opt{V} ) { say "=> Migrating Account Points."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Kudos Coins tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ kudos_coin_ledger / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 account_credits table;
    if ( defined $opt{V} ) { say "\t=> Pulling account credits records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT *, id as account_credit_id
         FROM account_credit_transactions
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $credit_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create image and save it.
        my $kudo = Side7::KudosCoin->new(
            id                => $row->{account_credit_id},
            user_id           => $row->{user_account_id},
            timestamp         => $row->{timestamp},
            amount            => $row->{amount},
            description       => $row->{description},
        );
        $kudo->save if ! defined $opt{D};

        $credit_count++;

        print _progress_dot( total => $row_count, count => $credit_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated account credit records: " . _commafy( $credit_count ) if defined $opt{V};
}

