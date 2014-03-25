#!/usr/bin/env perl

use strict;
use warnings;

use v5.18;
use lib '/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Side7::Globals;
use Side7::DB;
use Side7::User;
use Side7::User::Country;
use Side7::Account;
use Side7::UserContent::Image;

use Getopt::Std;
use Carp;
use Data::Dumper;
use DBI();
use Time::HiRes qw( gettimeofday tv_interval );
use POSIX qw( strftime );

use vars qw(
    $VERSION %opt $has_opts $DB4 $DB5
);

$VERSION = 1.00;

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

exit;

sub init
{
    # VALID OPTIONS = 'vhDVet'
    # [v]ersion, [h]elp, [D]ry-run, [V]erbose, [e]nvironment, [t]ime execution
    getopts( 'vhtDVe:', \%opt ) or HELP_MESSAGE();
    HELP_MESSAGE()    if $opt{h};
    VERSION_MESSAGE() if $opt{v};

    # Are any options set?
    $has_opts = 0;
    foreach my $key( qw( v h D V t e ) )
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
    migrate_images();
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

    if (defined $opt{V}) { say "I am attempting to connect to v5 >$environment< DB."; }

    $DB5 = Side7::DB->new( domain => $environment ) || croak 'Could not connect to new DB';

    my $v4_db   = 'side7_v4';
    my $v4_host = 'localhost';
    my $v4_un   = 's7old';
    my $v4_pw   = 's7CPR';

    $DB4 = DBI->connect("DBI:mysql:database=$v4_db;host=$v4_host", $v4_un, $v4_pw) 
        || croak 'Could not connect to old DB';

    if (defined $opt{V}) { say 'Connected to both the v4 and v5 databases.'; }
}

sub db_disconnect
{
    $DB4->disconnect() || croak 'Could not disconnect from v4 database.';

    if (defined $opt{V}) { say 'Disconnected to both the v4 and v5 databases.'; }
}

sub migrate_users
{
    if (defined $opt{V}) { say "=> Migrating Users."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if (defined $opt{V}) { say "\t=> Truncating v5 User and Account tables."; }
        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";
        foreach my $table ( qw/ accounts users / )
        {
            $dbh5->do("TRUNCATE TABLE $table");
        }
    }

    # Pull data from the v4 user_accounts table;
    if (defined $opt{V}) { say "\t=> Pulling user accounts from v4 DB."; }
    my $sth = $DB4->prepare(
        'SELECT ua.*, ua.id as user_id, uap.*
        FROM user_accounts ua 
        INNER JOIN user_account_personal_info uap
            ON uap.user_account_id = ua.id
        ORDER BY ua.id 
        '
    );
    $sth->execute();

    my %statuses = (
        Pending   => 1,
        Active    => 2,
        Suspended => 3,
        Disabled  => 4,
    );

    my %types = (
        1 => 1,
        2 => 1,
        3 => 2,
        4 => 3,
    );

    my %datevis = (
        'Full'    => 1,
        'No Year' => 2,
        'Hidden'  => 3,
    );

    my $user_count = 0;
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
            Side7::User::Country->new( name => substr($row->{country},0,45) )->load(speculative => 1) :
            0;
        if ( ref $country eq 'Side7::User::Country' )
        {
            $country_id = $country->{id};
        }
        my $birthday = '0000-00-00';
        if (
            defined $row->{birthdate} && 
            $row->{birthdate} ne '0000-00-00' &&
            $row->{birthdate} !~ m/0{2,4}/)
        {
            $birthday = $row->{birthdate};
        }

        my $account = Side7::Account->new(
            user_id        => $row->{user_id},
            first_name     => $row->{first_name},
            last_name      => $row->{last_name},
            user_type_id   => $types{$row->{access_control_list_id}},
            user_status_id => $statuses{$row->{status}},
            other_aliases  => $row->{alias},
            biography      => $row->{biography},
            sex            => $row->{sex},
            birthday       => $birthday,
            birthday_visibility => $datevis{$row->{birthdate_mode}},
            webpage_name   => $row->{webpage_name},
            webpage_url    => $row->{webpage_url},
            blog_name      => $row->{journal_name},
            blog_url       => $row->{journal_url},
            aim            => $row->{aim},
            yahoo          => $row->{yahoo},
            state          => $row->{state},
            country_id     => $country_id,
            is_public      => $row->{is_public},
            created_at     => $row->{join_date},
            updated_at     => $row->{modified_date},
        );
        $account->save if ! defined $opt{D};

        $user_count++;
    }

    $sth->finish();
    say "=> Migrated users & accounts: $user_count";
}

sub migrate_images
{
    if (defined $opt{V}) { say "=> Migrating Images."; }

    # Cleanup from any previous migrations.
    if ( ! defined $opt{D} )
    {
        if (defined $opt{V}) { say "\t=> Truncating v5 Image tables."; }
        my $dbh5 = $DB5->dbh || croak "Unable to establish DB5 handle: $DB5->error";
        foreach my $table ( qw/ images / )
        {
            $dbh5->do("TRUNCATE TABLE $table");
        }
    }

    # Pull data from the v4 user_accounts table;
    if (defined $opt{V}) { say "\t=> Pulling image records from v4 DB."; }
    my $sth = $DB4->prepare(
        'SELECT *, id as image_id
         FROM images
         ORDER BY images.id 
        '
    );
    $sth->execute();

    my $image_count = 0;
    while ( my $row = $sth->fetchrow_hashref() )
    {
        # Some conversion and clean up.
        my $privacy = 'Public';
        if ( uc($row->{friends_only}) eq 'TRUE' )
        {
            $privacy = 'Friends Only';
        }

        my $archived = ( uc($row->{is_archived}) eq 'TRUE' ) ? 1 : 0;

        # Create image and save it.
        my $image = Side7::UserContent::Image->new(
            id             => $row->{image_id},
            user_id        => $row->{user_account_id},
            filename       => $row->{filename},
            title          => $row->{title},
            filesize       => $row->{filesize},
            dimensions     => $row->{dimensions},
            category_id    => $row->{image_category_id},
            rating_id      => $row->{image_rating_id},
            stage_id       => $row->{image_class_id},
            description    => $row->{description},
            privacy        => $privacy,
            is_archived    => $archived,
            copyright_year => $row->{copyright_year},
            created_at     => $row->{uploaded_date},
            updated_at     => $row->{last_modified_date},
        );
        $image->save if ! defined $opt{D};

        $image_count++;
    }

    $sth->finish();
    say "=> migrated images: $image_count";
}

sub time_elapsed
{
    my $elapsed = shift;
    my $time = strftime("%h:%m:%s", gmtime($elapsed));

    return "elapsed migration time: $time";
}

sub HELP_MESSAGE
{
    say "usage: perl $0 [-DehVv] [file ...]";
    say '[v]ersion, [h]elp, [D]ry-run, [V]erbose, [e]nvironment, [t]ime execution';
    say '';
    exit;
}

sub VERSION_MESSAGE
{
    say "$0 version $VERSION";
    say '';
    exit;
}
