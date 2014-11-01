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
use Side7::UserContent::Album;
use Side7::UserContent::AlbumImageMap;
use Side7::UserContent::Category;
use Side7::KudosCoin;
use Side7::Utils::Text;
use Side7::FAQCategory;
use Side7::FAQEntry;
use Side7::News;
use Side7::PrivateMessage;

use Getopt::Std;
use Carp;
use Data::Dumper;
use DBI();
use Time::HiRes qw( gettimeofday tv_interval );
use DateTime;
use Digest::MD5;
use IO::File;
use Cwd;
use Try::Tiny;

use vars qw(
    $VERSION %opt $has_opts $DB4 $DB5 %ID_TRANSLATIONS $CWD %packages
);

$|++;

$VERSION = 1.50;

%packages = (
                news            => 'migrate_news',
                users           => 'migrate_users',
                user_prefs      => 'migrate_user_preferences',
                acct_creds      => 'migrate_account_credits',
                images          => 'migrate_images',
                image_views     => 'migrate_image_views',
                image_props     => 'migrate_image_properties',
                image_comments  => 'migrate_image_comments',
                image_c_threads => 'migrate_image_comment_threads',
                albums          => 'migrate_albums',
                album_images    => 'migrate_album_images',
                rigs            => 'migrate_related_image_groups',
                rig_images      => 'migrate_related_image_group_images',
                faq_cats        => 'migrate_faq_categories',
                faq_entries     => 'migrate_faq_entries',
                private_msgs    => 'migrate_private_messages',
            );

init();

my $start = [];

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
    # VALID OPTIONS = 'vHhDVetlLp'
    # [v]ersion, [Hh]elp, [D]ry-run, [V]erbose, [e]nvironment, [t]ime execution, [l]arge tables included, [L]arge tables ONLY, [p]ackage(s) to run
    Getopt::Std::getopts( 'vHhtDVe:lLp:', \%opt ) || HELP_MESSAGE();

    if ( defined $opt{H} || defined $opt{h} )
    {
        HELP_MESSAGE();
    }
    VERSION_MESSAGE() if defined $opt{v};

    # Are any options set?
    $has_opts = 0;
    foreach my $key( qw( v H h D V t e L l p ) )
    {
        if ( defined $opt{$key} )
        {
            $has_opts = 1;
            last;
        }
    }

    $CWD = Cwd::getcwd();
}

sub migrate
{
    say "Side 7 v5 Migration Script";
    say "==========================";
    say "Copyright (C) 2013-2014 Side 7";
    say '';
    say 'This is a dry run. Nothing will be written to DB5.' if defined $opt{D};
    say '';
    say 'Current Working Directory is: >' . $CWD . '<' if defined $opt{V};
    say '' if defined $opt{V};

    sleep (3); # Dramatic pause

    db_connect();

    if ( defined $opt{p} )
    {
        # Migrate only specified parts of the data.
        if ( $opt{p} eq '' )
        {
            HELP_MESSAGE();
        }
        say '=> Migrating individual packages:';
        $opt{l} = 1; # Do this to ensure we can import large tables.
        foreach my $key ( split( /,\s*/, $opt{p} ) )
        {
            say "=> Attempting to migrate package >" . $key . '<' if defined $opt{V};
            if ( ! defined $packages{ lc( $key ) } )
            {
                say "=> ERROR: Invalid package name: >" . $key . '<';
                next;
            }
            try
            {
                eval $packages{ lc ( $key ) };
            }
            catch
            {
                croak 'Processing package for ' . $key . 'failed: ' . $_;
            };
        }
    }
    elsif ( defined $opt{L} )
    {
        # Large tables only
        migrate_image_views();
        migrate_image_properties();
    }
    else
    {
        # Potentially all tables
        migrate_news();
        migrate_users();
        migrate_user_preferences();
        migrate_account_credits();
        migrate_images();
        if ( defined $opt{l} )
        {
            migrate_image_views();
            migrate_image_properties();
        }
        migrate_image_comments();
        migrate_image_comment_threads();
        migrate_albums();
        migrate_album_images();
        migrate_related_image_groups();
        migrate_related_image_group_images();
        migrate_faq_categories();
        migrate_faq_entries();
        migrate_private_messages();
    }

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
            referred_by   => $row->{referred_by},
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
            created_at                 => DateTime->now(),
            updated_at                 => DateTime->now(),
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
        'SELECT *, images.id as image_id, category
         FROM images
         INNER JOIN image_categories ic ON image_category_id = ic.id
         ORDER BY images.id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $image_count = 0;

    my $bad_files_log = $CWD . '/migration_bad_checksum_files.log';
    my $bfl = IO::File->new("> $bad_files_log");

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

        my $content_directory = $CONFIG->{'general'}->{'base_gallery_directory'} .
            substr( $row->{'user_account_id'}, 0, 1 ) . '/' .
            substr( $row->{'user_account_id'}, 0, 3 ) . '/' .
            $row->{'user_account_id'} . '/';

        my $checksum = '';
        my $fh = new IO::File;
        if ( $fh->open( '< ' . $content_directory . $row->{'filename'} ) )
        {
            binmode ($fh);
            $checksum = Digest::MD5->new->addfile($fh)->hexdigest();
        }
        else
        {
            if ( defined $bfl )
            {
                print $bfl "Can't open >" . $content_directory . $row->{'filename'} . "< (ID: $row->{'image_id'}) for checksum: $!\n";
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
            category_id       => _get_new_image_category_id( $row->{category} ),
            rating_id         => $row->{image_rating_id},
            rating_qualifiers => ( $qualifiers // undef ),
            stage_id          => $row->{image_class_id},
            description       => $row->{description},
            privacy           => $privacy,
            is_archived       => $archived,
            copyright_year    => $row->{copyright_year},
            checksum          => $checksum,
            created_at        => $row->{uploaded_date},
            updated_at        => $row->{last_modified_date},
        );
        $image->save if ! defined $opt{D};

        $image_count++;

        print _progress_dot( total => $row_count, count => $image_count, interval => $interval ) if defined $opt{V};
    }
    if ( defined $bfl )
    {
        $bfl->close();
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated images: " . _commafy( $image_count ) if defined $opt{V};
}

sub migrate_image_views
{
    if ( defined $opt{V} ) { say "=> Migrating Image Views."; }

    if ( ! defined $opt{l} && ! defined $opt{L} )
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

    if ( ! defined $opt{l} && ! defined $opt{L} )
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

#    if ( ! defined $opt{l} && ! defined $opt{L} )
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

#    if ( ! defined $opt{l} && ! defined $opt{L} )
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

sub migrate_albums
{
    if ( defined $opt{V} ) { say "=> Migrating Image Portfolios."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Albums tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ albums album_image_map album_music_map album_words_map / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 account_credits table;
    if ( defined $opt{V} ) { say "\t=> Pulling image portfolio records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT ip.*, ip.id as image_portfolio_id, ipt.name
         FROM image_portfolios ip
         INNER JOIN image_portfolio_types ipt
         ON ip.image_portfolio_type_id = ipt.id
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $album_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.
        my %albums = (
            1 => { name => undef, description => undef, system => undef },
            2 => { name => undef, description => undef, system => undef },
            3 => {
                    name        => 'Art Trades',
                    description => 'User Content traded or commissioned.',
                    system      => 1,
                 },
            4 => { name => undef, description => undef, system => undef },
            5 => { name => undef, description => undef, system => undef },
            6 => { name => undef, description => undef, system => undef },
            7 => { name => undef, description => undef, system => undef },
        );

        # Create album and save it.
        if ( $row->{'image_portfolio_type_id'} == 3 )
        {
            my $album = Side7::UserContent::Album->new(
                user_id           => $row->{user_account_id},
                name              => $albums{$row->{'image_portfolio_type_id'}}{name},
                description       => $albums{$row->{'image_portfolio_type_id'}}{description},
                system            => $albums{$row->{'image_portfolio_type_id'}}{system},
                created_at        => DateTime->now(),
                updated_at        => DateTime->now(),
            );
            $album->save if ! defined $opt{D};

            $ID_TRANSLATIONS{ $row->{image_portfolio_id} } = $album->id;

            $album_count++;

            print _progress_dot( total => $row_count, count => $album_count, interval => $interval ) if defined $opt{V};
        }

    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated album records: " . _commafy( $album_count ) if defined $opt{V};
}

sub migrate_album_images
{
    if ( defined $opt{V} ) { say "=> Migrating Image Portfolio Associations."; }

    # Cleanup from any previous migrations occurred with Album migration.

    # Pull data from the v4 image_portfolio_image_associations table;
    if ( defined $opt{V} ) { say "\t=> Pulling image portfolio association records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT ipia.*, ip.image_portfolio_type_id
         FROM image_portfolio_image_associations ipia
         INNER JOIN image_portfolios ip
         ON ip.id = ipia.image_portfolio_id
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $map_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create album and save it.
        if ( $row->{'image_portfolio_type_id'} == 3 )
        {
            my $map = Side7::UserContent::AlbumImageMap->new(
                album_id          => $ID_TRANSLATIONS{ $row->{image_portfolio_id} },
                image_id          => $row->{image_id},
                created_at        => DateTime->now(),
                updated_at        => DateTime->now(),
            );
            $map->save if ! defined $opt{D};

            $map_count++;

            print _progress_dot( total => $row_count, count => $map_count, interval => $interval ) if defined $opt{V};
        }

    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated album-image map records: " . _commafy( $map_count ) if defined $opt{V};
    %ID_TRANSLATIONS = (); # Clear out the translations
}

sub migrate_related_image_groups
{
    if ( defined $opt{V} ) { say "=> Migrating Related Image Groups."; }

    # Cleanup from any previous migrations will not be done; it's done with the Album migratio..

    # Pull data from the v4 account_credits table;
    if ( defined $opt{V} ) { say "\t=> Pulling related image group records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT rig.*, rig.id as related_image_group_id
         FROM related_images_groups rig
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $album_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create album and save it.
        my $album = Side7::UserContent::Album->new(
            user_id           => $row->{user_account_id},
            name              => $row->{name},
            description       => '',
            system            => 0,
            created_at        => DateTime->now(),
            updated_at        => DateTime->now(),
        );
        $album->save if ! defined $opt{D};

        $ID_TRANSLATIONS{ $row->{'related_image_group_id'} } = $album->id;

        $album_count++;

        print _progress_dot( total => $row_count, count => $album_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated album records: " . _commafy( $album_count ) if defined $opt{V};
}

sub migrate_related_image_group_images
{
    if ( defined $opt{V} ) { say "=> Migrating Image Portfolio Associations."; }

    # Cleanup from any previous migrations occurred with Album migration.

    # Pull data from the v4 image_portfolio_image_associations table;
    if ( defined $opt{V} ) { say "\t=> Pulling related image group association records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT riga.*
         FROM related_image_group_associations riga
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $map_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create album and save it.
        my $map = Side7::UserContent::AlbumImageMap->new(
            album_id          => $ID_TRANSLATIONS{ $row->{related_images_group_id} },
            image_id          => $row->{image_id},
            created_at        => DateTime->now(),
            updated_at        => DateTime->now(),
        );
        $map->save if ! defined $opt{D};

        $map_count++;

        print _progress_dot( total => $row_count, count => $map_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated album-image map records: " . _commafy( $map_count ) if defined $opt{V};
    %ID_TRANSLATIONS = (); # Clear out the translations
}

sub migrate_faq_categories
{
    if ( defined $opt{V} ) { say "=> Migrating FAQ Categories."; }

    # Cleanup from any previous migrations occurred with Album migration.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 FAQ Category tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ faq_categories / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 image_portfolio_image_associations table;
    if ( defined $opt{V} ) { say "\t=> Pulling FAQ Category records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT fc.*, fc.id as fc_id
         FROM faq_categories fc
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 ) || 1;

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $category_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create Category and save it.
        my $category = Side7::FAQCategory->new(
            id         => $row->{fc_id},
            name       => $row->{name},
            priority   => $row->{priority},
            created_at => DateTime->now(),
            updated_at => DateTime->now(),
        );
        $category->save if ! defined $opt{D};

        $category_count++;

        print _progress_dot( total => $row_count, count => $category_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated FAQ Category records: " . _commafy( $category_count ) if defined $opt{V};
}

sub migrate_faq_entries
{
    if ( defined $opt{V} ) { say "=> Migrating FAQ Entries."; }

    # Cleanup from any previous migrations occurred with Album migration.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 FAQ Entry tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ faq_entries / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 image_portfolio_image_associations table;
    if ( defined $opt{V} ) { say "\t=> Pulling FAQ Entry records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT fe.*, fe.id as fe_id
         FROM faq_entries fe
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $entry_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create Entry and save it.
        my $entry = Side7::FAQEntry->new(
            id              => $row->{fe_id},
            faq_category_id => $row->{faq_category_id},
            question        => $row->{question},
            answer          => $row->{answer},
            priority        => $row->{priority},
            created_at      => DateTime->now(),
            updated_at      => DateTime->now(),
        );
        $entry->save if ! defined $opt{D};

        $entry_count++;

        print _progress_dot( total => $row_count, count => $entry_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated FAQ Entry records: " . _commafy( $entry_count ) if defined $opt{V};
}

sub migrate_news
{
    if ( defined $opt{V} ) { say "=> Migrating Site News."; }

    # Cleanup from any previous migrations occurred with News migration.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 News tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ news / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 news table;
    if ( defined $opt{V} ) { say "\t=> Pulling News records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT news.*, news.id as news_id
         FROM news
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $entry_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.

        # Create Entry and save it.
        my $entry = Side7::News->new(
            id               => $row->{news_id},
            title            => $row->{title},
            blurb            => $row->{blurb},
            body             => $row->{article},
            link_to_article  => $row->{external_link},
            is_static        => $row->{static},
            not_static_after => $row->{expires},
            priority         => $row->{priority},
            user_id          => $row->{user_account_id},
            created_at       => $row->{timestamp},
            updated_at       => $row->{timestamp},
        );
        $entry->save if ! defined $opt{D};

        $entry_count++;

        print _progress_dot( total => $row_count, count => $entry_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated News records: " . _commafy( $entry_count ) if defined $opt{V};
}

sub migrate_private_messages
{
    if ( defined $opt{V} ) { say "=> Migrating Private Messages."; }

    # Cleanup from any previous migrations occurred with News migration.
    if ( ! defined $opt{D} )
    {
        if ( defined $opt{V} ) { say "\t=> Truncating v5 Private Messages tables."; }

        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";

        foreach my $table ( qw/ private_messages / )
        {
            $dbh5->do( "TRUNCATE TABLE $table" );
        }
    }

    # Pull data from the v4 news table;
    if ( defined $opt{V} ) { say "\t=> Pulling Private Message records from v4 DB."; }

    my $sth = $DB4->prepare(
        'SELECT forum_private_messages.*, forum_private_messages.id as pm_id
         FROM forum_private_messages
         ORDER BY id'
    );
    $sth->execute();

    my $row_count = $sth->rows();
    my $interval  = int( $row_count / 10 );

    if ( defined $opt{V} ) { say "\t=> Pulled " . _commafy( $row_count ) . ' records from v4 DB.'; }

    my $entry_count = 0;

    print "\t=> Inserting records into v5 DB " if defined $opt{V};
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.
        my $status = 'Delivered';
        my $read_at    = undef;
        my $replied_at = undef;
        my $deleted_at = undef;
        if ( lc( $row->{'is_read'} ) eq 'true' )
        {
            $status  = 'Read';
            $read_at = $row->{'timestamp'};
        }
        if ( lc( $row->{'is_replied_to'} ) eq 'true' )
        {
            $status     = 'Replied To';
            $replied_at = $row->{'timestamp'};
        }
        if ( lc( $row->{'is_deleted'} ) eq 'true' )
        {
            $status     = 'Deleted';
            $deleted_at = $row->{'timestamp'};
        }

        # Create Entry and save it.
        my $entry = Side7::PrivateMessage->new(
            id               => $row->{pm_id},
            sender_id        => $row->{sender_user_account_id},
            recipient_id     => $row->{recipient_user_account_id},
            subject          => $row->{subject},
            body             => $row->{body},
            status           => $status,
            created_at       => $row->{timestamp},
            read_at          => $read_at,
            replied_at       => $replied_at,
            deleted_at       => $deleted_at,
        );
        $entry->save if ! defined $opt{D};

        $entry_count++;

        print _progress_dot( total => $row_count, count => $entry_count, interval => $interval ) if defined $opt{V};
    }
    print "\n" if defined $opt{V};

    $sth->finish();
    say "\t=> Migrated Private Message records: " . _commafy( $entry_count ) if defined $opt{V};
}

sub time_elapsed
{
    my $elapsed = shift;
    my $time = sprintf("%02d:%02d:%02d", (gmtime($elapsed))[2,1,0]);

    return "Elapsed migration time: $time";
}

sub HELP_MESSAGE
{
    say '';
    say "usage: $0 [-vHDVtlL] [-e <environment>] [-p <package(s)>";
    say '-v             Reports the script version.';
    say '-Hh            Displays this help message.';
    say '-D             Runs in dry-run mode, saving no data to the database.';
    say '-V             Runs in verbose mode.';
    say '-e <environ>   Establishes which environment to run the script; defaults to \'development\'';
    say '-t             Reports elapsed execution time';
    say '-l             Includes large tables in the migration (>500k rows).';
    say '-L             Import large tables ONLY in the migration (>500k rows).';
    say '-p <package>   Name specific packages to import, comma-separated with no white-space. Defaults to none.';
    say '';
    say 'Valid package names:';
    my $count = 1;
    my $output = '';
    foreach my $key ( sort keys %packages )
    {
        if ( $count == 1 )
        {
            $output = "\t\t";
        }
        $output .= $key . ', ';
        if ( $count == 6 )
        {
            say $output;
            $output = '';
            $count  = 1;
        }
        else
        {
            $count++;
        }
    }
    say '';
    exit 0;
}

sub VERSION_MESSAGE
{
    say "$0 version $VERSION";
    exit 0;
}

# PRIVATE FUNCTIONS

# This function takes the image category name, and looks up the new ID for it in the v5 DB.
sub _get_new_image_category_id
{
    my ( $category ) = @_;

    die 'Did not get a category name' if ! defined $category;

    my $new_category = Side7::UserContent::Category->new( category => $category, content_type => 'image' );
    my $loaded = $new_category->load( speculative => 1 );

    die 'Invalid category name >' . $category . '<; no image category found.' if $loaded == 0;

    return $new_category->id();
}

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

    return if ! defined $binary;

    # SPLIT THE BINARY NUMBER INTO DIGITS, AND PUT INTO AN ARRAY FOR SORTING
    @values = split( //, $binary );

    # REVERSE THE VALUES INTO THE PROPER ORDER
    @values = reverse @values;

    # PUSH THE VALUES INTO A HASH
    $i = 0;
    foreach my $value ( @values )
    {
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

    $params{'number'} || return;

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
