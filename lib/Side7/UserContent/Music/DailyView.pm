package Side7::UserContent::Music::DailyView;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use DateTime;

use Side7::Globals;
use Side7::UserContent::Music::DailyView::Manager;

use version; our $VERSION = qv( '0.1.0' );

=pod


=head1 NAME

Side7::UserContent::Music::DailyView


=head1 DESCRIPTION

This package represents daily total music view counts.


=head1 SCHEMA INFORMATION

    Table name: music_daily_views

    | id         | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | music_id   | bigint(20) unsigned | NO   |     | NULL    |                |
    | views      | bigint(20) unsigned | NO   | MUL | NULL    |                |
    | date       | date                | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Music

References the Music object via the music_id foreign key.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'music_daily_views',
    columns => [
        id       => { type => 'integer',                not_null => 1 },
        music_id => { type => 'integer', length => 45,  not_null => 1 },
        views    => { type => 'integer', length => 255, not_null => 1 },
        date     => { type => 'date',                   not_null => 1 },
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


=head2 get_total_views()

    my $total_views = Side7::UserContent::Music::DailyView::get_total_views( music_id => $music_id );

Returns an integer of the sum total views for an music.

=cut

sub get_total_views_count
{
    my ( %args ) = @_;

    my $music_id = delete $args{'music_id'} // undef;

    return if ! defined $music_id;

    my $total_views = Side7::DB::build_my_select(
        select  => 'SUM(views) as total_views',
        tables  => [ 'music_daily_views' ],
        columns => { music_daily_views => [ 'music_id', 'views' ] },
        query   => [ music_id => $music_id ],
        bind    => [ ],
        limit   => 1,
    );

    return $total_views->[0]->{'total_views'} // 0;
}


=head2 update_daily_views

    my $updated = Side7::UserContent::Music::DailyView::update_daily_views( music_id => $music_id );

Inserts or updates a daily view record for a given music.

=cut

sub update_daily_views
{
    my ( %args ) = @_;

    my $music_id = delete $args{'music_id'} // undef;

    return if ! defined $music_id;

    my $datetime = DateTime->today();

    my $daily_view = Side7::UserContent::Music::DailyView->new( music_id => $music_id, date => $datetime->ymd() );
    my $loaded = $daily_view->load( speculative => 1, for_update => 1,  );

    if ( $loaded != 0 )
    {
        $daily_view->views( $daily_view->views + 1 );
    }
    else
    {
        $daily_view->views( 1 );
    }

    $daily_view->save();

    return 1;
}

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
