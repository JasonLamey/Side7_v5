package Side7::Admin::Report;

use strict;
use warnings;

use DateTime;
use Rose::DB::Object::QueryBuilder qw( build_select );
use Data::Dumper;

use Side7::Globals;

use version; our $VERSION = qv( '0.1.3' );

=pod


=head1 NAME

Side7::Admin::Report


=head1 DESCRIPTION

TODO: Define a package description.


=head1 RELATIONSHIPS

=over

=item Class::Name

TODO: Define the relationship type, and list the foreign key (FK).

=back

=cut


=head1 METHODS


=head2 method_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package->method_name();

=cut

sub method_name
{
}


=head1 FUNCTIONS


=head2 get_uptime()

Returns a string with the server uptime information.

Parameters:

=over 4

=item none

=back

=cut

sub get_uptime
{
    my $uptime = `uptime`;

    return $uptime;
}


=head2 get_who()

Returns a string with logged in users list.

Parameters:

=over 4

=item none

=back

=cut

sub get_who
{
    my $who = `who`;

    return $who;
}


=head2 get_user_account_stats()

Returns a hashref with the user account stats information.

Parameters:

=over 4

=item none

=back

=cut

sub get_user_account_stats
{
    my %user_stats = ();

    # Total Users
    $user_stats{'total_users'} = Side7::User::Manager::get_users_count();

    my $dbh = $DB->dbh();

    # Counts by User Type
    my @user_type_counts = ();
    my $type_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_users, user_type',
                                tables  => [ 'users', 'accounts', 'user_types' ],
                                classes => {
                                                users      => 'Side7::User',
                                                accounts   => 'Side7::Account',
                                                user_types => 'Side7::User::Type',
                                           },
                                columns => { users => [], accounts => [], user_types => [ 'user_type' ], },
                                clauses => [
                                                't1.id = t2.user_id',
                                                't2.user_type_id = t3.id',
                                           ],
                                group_by => 'user_type',
                             );

    my $type_sth = $dbh->prepare( $type_sql );
    $type_sth->execute;

    while ( my $row = $type_sth->fetchrow_hashref )
    {
        push ( @user_type_counts, { user_type => $row->{'user_type'}, num_users => $row->{'num_users'} } );
    }

    $user_stats{'total_by_type'} = \@user_type_counts;

    # Counts by User Status
    my @user_status_counts = ();
    my $status_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_users, user_status',
                                tables  => [ 'users', 'accounts', 'user_statuses' ],
                                classes => {
                                                users         => 'Side7::User',
                                                accounts      => 'Side7::Account',
                                                user_statuses => 'Side7::User::Status',
                                           },
                                columns => { users => [], accounts => [], user_statuses => [ 'user_status' ], },
                                clauses => [
                                                't1.id = t2.user_id',
                                                't2.user_status_id = t3.id',
                                           ],
                                group_by => 'user_status',
                             );

    my $status_sth = $dbh->prepare( $status_sql );
    $status_sth->execute;

    while ( my $row = $status_sth->fetchrow_hashref )
    {
        push ( @user_status_counts, { user_status => $row->{'user_status'}, num_users => $row->{'num_users'} } );
    }

    $user_stats{'total_by_status'} = \@user_status_counts;

    # Counts by User Role
    my @user_role_counts = ();
    my $role_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_users, name',
                                tables  => [ 'users', 'accounts', 'user_roles' ],
                                classes => {
                                                users      => 'Side7::User',
                                                accounts   => 'Side7::Account',
                                                user_roles => 'Side7::User::Role',
                                           },
                                columns => { users => [], accounts => [], user_roles => [ 'name' ], },
                                clauses => [
                                                't1.id = t2.user_id',
                                                't2.user_role_id = t3.id',
                                           ],
                                group_by => 'name',
                             );

    my $role_sth = $dbh->prepare( $role_sql );
    $role_sth->execute;

    while ( my $row = $role_sth->fetchrow_hashref )
    {
        push ( @user_role_counts, { user_role => $row->{'name'}, num_users => $row->{'num_users'} } );
    }

    $user_stats{'total_by_role'} = \@user_role_counts;

    return \%user_stats;
}


=head2 get_thirty_day_new_and_deleted_users()

Returns a hashref of arrayrefs of hashrefs of data pertaining to the daily totals of new and deleted users.

Parameters:

=over 4

=item none

=back

    my $new_and_deleted_users = Side7::Admin::Report::get_thirty_day_new_and_deleted_users();

=cut

sub get_thirty_day_new_and_deleted_users
{
    my %user_data = ();

    my $today           = DateTime->today->add( days => 1 );
    my $thirty_days_ago = DateTime->today->subtract( days => 30 );

    # Date Range Array
    my @date_range = ();
    foreach my $interval ( reverse( 0 .. 30 ) )
    {
        my $date = DateTime->today->subtract( days => $interval )->ymd();
        push ( @date_range, $date );
    }

    my ( $year, $month, $day ) = split( /-/, $date_range[0] );
    $month -= 1;

    $user_data{'start_date'} = join( ', ', ( $year, $month, $day ) );

    my $dbh = $DB->dbh();
    my $nu_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_users, DATE( created_at ) AS created_at',
                                tables  => [ 'users' ],
                                classes => { users => 'Side7::User' },
                                columns => { users => [ qw( created_at ) ] },
                                query => [
                                            created_at => { ge => $thirty_days_ago },
                                            created_at => { le => $today },
                                         ],
                                order_by => 'created_at ASC',
                                group_by => 'created_at',
                             );

    my $nu_sth = $dbh->prepare( $nu_sql );
    $nu_sth->execute;

    my %found_new_users;
    while ( my $row = $nu_sth->fetchrow_hashref )
    {
        $found_new_users{$row->{'created_at'}} = $row->{'num_users'};
    }

    my @new_users = ();
    foreach my $date ( @date_range )
    {
        my $count = 0;
        if ( defined $found_new_users{ $date } )
        {
            $count = $found_new_users{ $date };
        }
        push ( @new_users, $count );
    }

    $user_data{'new_users'} = join( ',', @new_users );

    my $du_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_users, DATE( timestamp ) AS timestamp',
                                tables  => [ 'audit_logs' ],
                                classes => { audit_logs => 'Side7::AuditLog' },
                                columns => { audit_logs => [ qw( title timestamp ) ] },
                                query => [
                                            timestamp => { ge => $thirty_days_ago },
                                            timestamp => { le => $today },
                                            title     => { like => '%User Purged%' },
                                         ],
                                order_by => 'timestamp ASC',
                                group_by => 'timestamp',
                             );

    my $du_sth = $dbh->prepare( $du_sql );
    $du_sth->execute;

    my %found_del_users;
    while ( my $row = $du_sth->fetchrow_hashref )
    {
        $found_del_users{$row->{'timestamp'}} = $row->{'num_users'};
    }

    my @deleted_users = ();
    foreach my $date ( @date_range )
    {
        my $count = 0;
        if ( defined $found_del_users{ $date } )
        {
            $count = $found_del_users{ $date };
        }
        push ( @deleted_users, $count );
    }

    $user_data{'deleted_users'} = join( ',', @deleted_users );

    return \%user_data;
}


=head2 get_thirty_day_new_content()

Returns a hashref of data to be displayed on the primary Admin dashboard.

Parameters:

=over 4

=item none

=back

    my $content_uploads = Side7::Admin::Report::get_thirty_day_new_content();

=cut

sub get_thirty_day_new_content
{
    my %content_data = ();

    my $today           = DateTime->today->add( days => 1 );
    my $thirty_days_ago = DateTime->today->subtract( days => 30 );

    # Date Range Array
    my @date_range = ();
    foreach my $interval ( reverse( 0 .. 30 ) )
    {
        my $date = DateTime->today->subtract( days => $interval )->ymd();
        push ( @date_range, $date );
    }

    my ( $year, $month, $day ) = split( /-/, $date_range[0] );
    $month -= 1;

    $content_data{'start_date'} = join( ', ', ( $year, $month, $day ) );

    my $dbh = $DB->dbh();

    # Image Data
    my $i_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_images, DATE( created_at ) AS created_at',
                                tables  => [ 'images' ],
                                classes => { images => 'Side7::UserContent::Image' },
                                columns => { images => [ qw( created_at ) ] },
                                query => [
                                            created_at => { ge => $thirty_days_ago },
                                            created_at => { le => $today },
                                         ],
                                order_by => 'created_at ASC',
                                group_by => 'DATE( created_at )',
                             );

    my $i_sth = $dbh->prepare( $i_sql );
    $i_sth->execute;

    my %images = ();
    while ( my $row = $i_sth->fetchrow_hashref )
    {
        $images{$row->{'created_at'}} = $row->{'num_images'};
    }

    # Music Data
    my $m_sql = build_select(
                                db      => $DB,
                                dbh     => $dbh,
                                select  => 'COUNT( 1 ) AS num_music, DATE( created_at ) AS created_at',
                                tables  => [ 'music' ],
                                classes => { music => 'Side7::UserContent::Music' },
                                columns => { music => [ qw( created_at ) ] },
                                query => [
                                            created_at => { ge => $thirty_days_ago },
                                            created_at => { le => $today },
                                         ],
                                order_by => 'created_at ASC',
                                group_by => 'DATE( created_at )',
                             );

    my $m_sth = $dbh->prepare( $m_sql );
    $m_sth->execute;

    my %music = ();
    while ( my $row = $m_sth->fetchrow_hashref )
    {
        $music{$row->{'created_at'}} = $row->{'num_music'};
    }

    # Literature Data

    # Totals
    my @images     = ();
    my @music      = ();
    my @literature = ();
    my @totals     = ();
    foreach my $date ( @date_range )
    {
        my $count  = 0;
        my $icount = 0;
        my $mcount = 0;
        my $lcount = 0;

        # Images
        if ( defined $images{ $date } )
        {
            $count += $images{ $date };
            $icount = $images{ $date };
        }
        push ( @images, $icount );

        # Music
        if ( defined $music{ $date } )
        {
            $count += $music{ $date };
            $mcount = $music{ $date };
        }
        push ( @music, $mcount );

        # Literature
        push ( @literature, $lcount );

        push ( @totals, $count );
    }

    $content_data{'totals'}     = join( ',', @totals );
    $content_data{'images'}     = join( ',', @images );
    $content_data{'music'}      = join( ',', @music );
    $content_data{'literature'} = join( ',', @literature );

    return \%content_data;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
