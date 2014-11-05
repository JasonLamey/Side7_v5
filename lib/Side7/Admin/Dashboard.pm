package Side7::Admin::Dashboard;

use strict;
use warnings;

use Data::Dumper;

use Side7::Globals;
use Side7::DB;
use Side7::AuditLog::Manager;
use Side7::User;
use Side7::User::Manager;
use Side7::User::Status::Manager;
use Side7::User::Type::Manager;
use Side7::User::Role::Manager;
use Side7::User::Country::Manager;
use Side7::DateVisibility::Manager;

use version; our $VERSION = qv( '0.1.6' );

=pod


=head1 NAME

Side7::Admin::Dashboard


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


=head2 get_main_menu()

Returns an arrayref of hashes with main menu options, their links, and enabled status.

Parameters:

=over 4

=item username: The session username of the User, so that a User Permissions can be retrieved and used for authorization.

=back

    my $main_menu = Side7::Admin::Dashboad::get_main_menu( username => $username );

=cut

sub get_main_menu
{
    my ( %args ) = @_;

    my $username = delete $args{'username'} // undef;

    return [] if ! defined $username;

    my $user = Side7::User::get_user_by_username( $username );

    my @main_menu_options = ();
    my $enabled = 0;

    # Home
    push ( @main_menu_options, { name => 'Admin Home', link => '/admin', enabled => 1 } );

    # Site News
    $enabled = ( $user->has_permission( 'can_post_site_news' ) ) ? 1 : 0;
    push ( @main_menu_options, { name => 'Manage News', link => '/admin/news', enabled => $enabled } );

    # Site Calendar
    $enabled = ( $user->has_permission( 'can_post_site_events' ) ) ? 1 : 0;
    push ( @main_menu_options, { name => 'Manage Calendar', link => '/admin/calendar', enabled => $enabled } );

    # Site FAQ
    $enabled = ( $user->has_permission( 'can_manage_faq_entries' ) ) ? 1 : 0;
    push ( @main_menu_options, { name => 'Manage FAQ', link => '/admin/faq', enabled => $enabled } );

    # Users
    $enabled = ( $user->has_permission( 'can_view_account_details' ) ) ? 1 : 0;
    push ( @main_menu_options, { name => 'Manage Users', link => '/admin/users', enabled => $enabled } );

    # View Audit Logs
    $enabled = ( $user->has_permission( 'can_view_audit_logs' ) ) ? 1 : 0;
    push ( @main_menu_options, { name => 'View Audit Logs', link => '/admin/audit_logs', enabled => $enabled } );

    return \@main_menu_options;
}


=head2 show_main_dashboard()

Returns a hashref of data to be displayed on the primary Admin dashboard.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $admin_data = Side7::Admin::Dashboard::show_main_dashboard();

=cut

sub show_main_dashboard
{
    my ( %args ) = @_;

    my %admin_data = ();

    # Quick Server Stats
    my $uptime = Side7::Admin::Report::get_uptime();
    my $who    = Side7::Admin::Report::get_who();

    # User Account Stats
    my $user_stats = Side7::Admin::Report::get_user_account_stats();

    # 30-Day New & Deleted User Accounts
    my $user_data = Side7::Admin::Report::get_thirty_day_new_and_deleted_users();

    # 30-Day New Content Uploads
    my $content_data = Side7::Admin::Report::get_thirty_day_new_content();

    $admin_data{'uptime'}       = $uptime;
    $admin_data{'who'}          = $who;
    $admin_data{'user_data'}    = $user_data;
    $admin_data{'user_stats'}   = $user_stats;
    $admin_data{'content_data'} = $content_data;

    return \%admin_data;
}


=head2 show_user_dashboard()

Returns a hashref of data to be displayed on the User Management dashboard.

Parameters:

=over 4

=item initial: The character with which the username should start. Defaults to '0'.

=item page: The page to display, for pagination within a particular initial filter.  Defaults to 1.

=back

    my $admin_data = Side7::Admin::Dashboard::show_user_dashboar();

=cut

sub show_user_dashboard
{
    my ( %args ) = @_;

    my $initial = delete $args{'initial'} // '0';
    my $page    = delete $args{'page'}    // 1;

    my %admin_data = ();

    my $initials = Side7::User::get_username_initials();

    my ( $users, $user_count ) = Side7::User::get_users_for_directory(
                                                                            initial          => $initial,
                                                                            page             => $page,
                                                                            no_images        => 1,
                                                                            filter_profanity => 0,
                                                                         );

    my @found_users = map { $_->{'user'} } @$users;

    my $statuses = Side7::Admin::Dashboard::get_user_statuses_for_select();
    my $roles    = Side7::Admin::Dashboard::get_user_roles_for_select();
    my $types    = Side7::Admin::Dashboard::get_user_types_for_select();

    return {
                users      => \@found_users,
                user_count => $user_count,
                initials   => $initials,
                statuses   => $statuses,
                roles      => $roles,
                types      => $types,
           };
};


=head2 get_user_statuses_for_select()

Returns a hashref of User Status IDs and names;

Parameters:

=over 4

=item None

=back

    my $statuses = Side7::Admin::Dashboard::get_user_statuses_for_select();

=cut

sub get_user_statuses_for_select
{
    my $statuses = Side7::User::Status::Manager->get_statuses(
                                                                sort_by => 'id',
                                                             );

    return $statuses;
}


=head2 get_user_roles_for_select()

Returns a hashref of User Roles IDs and names;

Parameters:

=over 4

=item None

=back

    my $statuses = Side7::Admin::Dashboard::get_user_roles_for_select();

=cut

sub get_user_roles_for_select
{
    my $roles = Side7::User::Role::Manager->get_roles(
                                                         sort_by => 'priority',
                                                       );

    return $roles;
}


=head2 get_user_types_for_select()

Returns a hashref of User Types IDs and names;

Parameters:

=over 4

=item None

=back

    my $types = Side7::Admin::Dashboard::get_user_types_for_select();

=cut

sub get_user_types_for_select
{
    my $types = Side7::User::Type::Manager->get_types(
                                                        sort_by => 'id',
                                                     );

    return $types;
}


=head2 get_user_sexes_for_select()

Returns a hashref of User Sex names;

Parameters:

=over 4

=item None

=back

    my $sexes = Side7::Admin::Dashboard::get_user_sexes_for_select();

=cut

sub get_user_sexes_for_select
{
    my $enums = {};

    my $sex_enums = Side7::DB::get_enum_values_for_form( fields => [ 'sex' ], table => 'accounts' );

    $enums = ( $sex_enums ); # Merging returned enum hash refs into one hash ref.

    return $enums;
}


=head2 get_countries_for_select()

Returns a hashref of Countries;

Parameters:

=over 4

=item None

=back

    my $countries = Side7::Admin::Dashboard::get_countries_for_select();

=cut

sub get_countries_for_select
{
    my $countries = Side7::User::Country::Manager->get_countries(
                                                                  sort_by => 'name',
                                                                );

    return $countries;
}


=head2 get_birthday_visibilities_for_select()

Returns a hashref of Birthday Visibilities;

Parameters:

=over 4

=item None

=back

    my $visibilities = Side7::Admin::Dashboard::get_birthday_visibilities_for_select();

=cut

sub get_birthday_visibilities_for_select
{
    my $visibilities = Side7::DateVisibility::Manager->get_date_visibilities(
                                                                                sort_by => 'id',
                                                                            );

    return $visibilities;
}


=head2 search_users()

Returns an hashref of user accounts that match the search criteria.

Parameters:

=over 4

=item search_term: A string containing the text for which to search in the username, first_name, last_name, and email.

=item status: The status ID upon which to search.

=item type: The type ID upon which to search.

=item role: The role ID upon which to search.

=item page: The page of results to return.

=back

    my $data = Side7::Admin::Dashboard::search_users(
                                                        search_term => $search_term,
                                                        status      => $status,
                                                        type        => $type,
                                                        role        => $role,
                                                        page        => $page,
                                                    );

=cut

sub search_users
{
    my ( %args ) = @_;

    my $search_term = delete $args{'search_term'} // undef;
    my $status      = delete $args{'status'}      // undef;
    my $type        = delete $args{'type'}        // undef;
    my $role        = delete $args{'role'}        // undef;
    my $page        = delete $args{'page'}        // 1;

    my %query = ();

    if ( defined $search_term && $search_term ne '' )
    {
        my $search = $search_term;
        $search =~ s/([\@\$\#\%])/\\$1/g;

        my %or = ();
        $or{'username'}           = { like => "%$search%" };
        $or{'email_address'}      = { like => "%$search%" };
        $or{'account.first_name'} = { like => "%$search%" };
        $or{'account.last_name'}  = { like => "%$search%" };

        $query{'or'} = [ %or ];
    }
    if ( defined $status && $status ne '' )
    {
        $query{'account.user_status_id'} = $status;
    }
    if ( defined $role && $role ne '' )
    {
        $query{'account.user_role_id'} = $role;
    }
    if ( defined $type && $type ne '' )
    {
        $query{'account.user_type_id'} = $type;
    }

    my $user_count = Side7::User::Manager->get_users_count(
        query        => [ %query ],
        with_objects => [ 'account' ],
    );

    my $users = Side7::User::Manager->get_users
    (
        query        => [ %query ],
        with_objects => [ 'account' ],
        sort_by      => 'username ASC',
        page         => $page,
        per_page     => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
    );

    my %data = ();

    $data{'users'}      = $users;
    $data{'user_count'} = $user_count;
    $data{'initials'}   = Side7::User::get_username_initials();
    $data{'statuses'}   = Side7::Admin::Dashboard::get_user_statuses_for_select();
    $data{'roles'}      = Side7::Admin::Dashboard::get_user_roles_for_select();
    $data{'types'}      = Side7::Admin::Dashboard::get_user_types_for_select();

    return \%data;
}


=head2 search_audit_logs()

Returns an hashref of audit logs that match the search criteria.

Parameters:

=over 4

=item search_term: A string containing the text for which to search in the title, description, user_id, and ip_address.

=item page: The page of results to return.

=back

    my $data = Side7::Admin::Dashboard::search_audit_logs(
                                                            search_term => $search_term,
                                                            page        => $page,
                                                         );

=cut

sub search_audit_logs
{
    my ( %args ) = @_;

    my $search_term = delete $args{'search_term'} // undef;
    my $page        = delete $args{'page'}        // 1;

    my %query = ();

    if ( defined $search_term && $search_term ne '' )
    {
        my $search = $search_term;
        $search =~ s/([\@\$\#\%])/\\$1/g;

        my %or = ();
        $or{'title'}       = { like => "%$search%" };
        $or{'description'} = { like => "%$search%" };
        $or{'user_id'}     = { like => "%$search%" };
        $or{'ip_address'}  = { like => "%$search%" };

        $query{'or'} = [ %or ];
    }

    my $log_count = Side7::AuditLog::Manager->get_audit_logs_count(
        query        => [ %query ],
        with_objects => [ 'user' ],
    );

    my $logs = Side7::AuditLog::Manager->get_audit_logs
    (
        query        => [ %query ],
        with_objects => [ 'user' ],
        sort_by      => 'timestamp DESC',
        page         => $page,
        per_page     => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
    );

    my @results = ();

    foreach my $log ( @{ $logs } )
    {
        my %rowhash = ();
        foreach my $key ( qw/ id timestamp title description affected_id original_value new_value user_id ip_address / )
        {
            if
            (
                $key eq 'title'
                ||
                $key eq 'description'
                ||
                $key eq 'user_id'
                ||
                $key eq 'ip_address'
            )
            {
                $rowhash{$key} = Side7::Search::highlight_match( text => $log->$key(), look_for => $search_term );
            }
            else
            {
                $rowhash{$key} = $log->$key;
            }
        }

        push( @results, \%rowhash );
    }

    my %data = ();

    $data{'logs'}      = \@results;
    $data{'log_count'} = $log_count;

    return \%data;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
