package Side7::Admin::Dashboard;

use strict;
use warnings;

use Side7::Globals;
use Side7::User;

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
    push ( @main_menu_options, { name => 'Home', link => '/admin', enabled => 1 } );

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


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
