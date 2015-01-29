package Side7::UserContent::Music::DetailedView;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use DateTime;

use Side7::Globals;
use Side7::UserContent::Music::DetailedView::Manager;

use version; our $VERSION = qv( '0.1.2' );

=pod


=head1 NAME

Side7::UserContent::Music::DetailedView


=head1 DESCRIPTION

This package represents detailed information on every view a User Content receives.


=head1 SCHEMA INFORMATION

    Table name: music_detailed_views

    | id         | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | music_id   | bigint(20) unsigned | NO   |     | NULL    |                |
    | user_id    | bigint(20) unsigned | YES  |     | NULL    |                |
    | ip_address | varchar(255)        | YES  |     | NULL    |                |
    | user_agent | varchar(255)        | YES  |     | NULL    |                |
    | referer    | text                | YES  |     | NULL    |                |
    | date       | date                | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Music

References the Music object via the music_id foreign key.

=item Side7::User

References the User object via the user_id foreign key.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'music_detailed_views',
    columns => [
        id         => { type => 'integer',                not_null => 1 },
        music_id   => { type => 'integer', length => 45,  not_null => 1 },
        user_id    => { type => 'integer', length => 45 },
        ip_address => { type => 'varchar', length => 255 },
        user_agent => { type => 'varchar', length => 255 },
        referer    => { type => 'varchar', length => 255 },
        date       => { type => 'date',                   not_null => 1 },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'music_id', 'date' ], [ 'music_id' ], [ 'date' ] ],
    relationships =>
    [
        music =>
        {
            type       => 'many to one',
            class      => 'Side7::UserContent::Music',
            column_map => { music_id => 'id' },
        },
        user =>
        {
            type       => 'many to one',
            class      => 'Side7::User',
            column_map => { user_id => 'id' },
        },
    ],
);


=head1 METHODS


=head2 method_name()

    my $result = My::Package->method_name();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub method_name
{
}


=head1 FUNCTIONS


=head2 add_detailed_view()

    my $added = Side7::UserContent::Music::DetailedView::add_detailed_view( music_id => $music_id, request => $request );

Returns a success value if view is inserted.

=cut

sub add_detailed_view
{
    my ( %args ) = @_;

    my $music_id = delete $args{'music_id'} // undef;
    my $request  = delete $args{'request'}  // {};
    my $session  = delete $args{'session'}  // {};

    return if ! defined $music_id;

    my $datetime = DateTime->today();

    my $ip_address = ( defined $request->{env}->{REMOTE_HOST} && $request->{env}->{REMOTE_HOST} )
                        ? $request->{env}->{REMOTE_ADDR} . ':' . $request->{env}->{REMOTE_HOST}
                        : $request->{env}->{REMOTE_ADDR};

    my $detailed_view = Side7::UserContent::Music::DetailedView->new(
        music_id   => $music_id,
        user_id    => $session->{user_id},
        ip_address => $ip_address,
        user_agent => $request->{user_agent},
        referer    => $request->{referer},
        date       => $datetime->ymd(),
    );

    $detailed_view->save();

    return 1;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
