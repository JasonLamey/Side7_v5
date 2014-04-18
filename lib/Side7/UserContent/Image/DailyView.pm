package Side7::UserContent::Image::DailyView;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use DateTime;

use Side7::Globals;
use Side7::UserContent::Image::DailyView::Manager;

=pod

=head1 NAME

Side7::UserContent::Image::DailyView

=head1 DESCRIPTION

This package represents daily total image view counts.

=head1 SCHEMA INFORMATION

    Table name: image_daily_views
     
    | id         | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | image_id   | bigint(20) unsigned | NO   |     | NULL    |                |
    | views      | bigint(20) unsigned | NO   | MUL | NULL    |                |
    | date       | date                | NO   |     | NULL    |                |

=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Image

References the Image object via the image_id foreign key.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'image_daily_views',
    columns => [ 
        id       => { type => 'integer',                not_null => 1 },
        image_id => { type => 'integer', length => 45,  not_null => 1 }, 
        views    => { type => 'integer', length => 255, not_null => 1 }, 
        date     => { type => 'date',                   not_null => 1 }, 
    ],
    pk_columns => 'id',
    unique_key => [ [ 'image_id', 'date' ], [ 'image_id' ], [ 'date' ] ],
    relationships =>
    [
        image =>
        {
            type       => 'many to one',
            class      => 'Side7::UserContent::Image',
            column_map => { image_id => 'id' },
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

    my $total_views = Side7::UserContent::Image::DailyView::get_total_views( image_id => $image_id );

Returns an integer of the sum total views for an image.

=cut

sub get_total_views_count
{
    my ( %args ) = @_;

    my $image_id = delete $args{'image_id'};

    return if ! defined $image_id;

    my $total_views = Side7::DB::build_select(
        select  => 'SUM(views) as total_views',
        tables  => [ 'image_daily_views' ],
        columns => { image_daily_views => [ 'image_id', 'views' ] },
        query   => [ image_id => $image_id ],
        bind    => [ ],
        limit   => 1,
    );

    return $total_views->[0]->{'total_views'} // 0;
}


=head2 update_daily_views

    my $updated = Side7::UserContent::Image::DailyView::update_daily_views( image_id => $image_id );

Inserts or updates a daily view record for a given image.

=cut

sub update_daily_views
{
    my ( %args ) = @_;

    my $image_id = delete $args{'image_id'};

    return if ! defined $image_id;

    my $datetime = DateTime->today();

    my $daily_view = Side7::UserContent::Image::DailyView->new( image_id => $image_id, date => $datetime->ymd() );
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
