package Side7::Report;

use strict;
use warnings;

use Rose::DB::Object::QueryBuilder qw( build_select );

use Data::Dumper;

use Side7::Globals;

use version; our $VERSION = qv( '0.1.2' );


=pod


=head1 NAME

Side7::Report


=head1 DESCRIPTION

This package defines functions for returning data sets for NON-ADMIN reports and graphs.


=head1 METHODS


=head2 get_user_content_breakdown_by_category()

This method returns a hashref of data of all content belonging to a User, broken out by content type, and then
by content category.

Parameters:

=over 4

=item user_id: The User ID to use for look-up.

=back

    my $content_by_category = Side7::Report->get_user_content_breakdown_by_category( $user_id );

=cut

sub get_user_content_breakdown_by_category
{
    my ( $self, $user_id ) = @_;

    return {} if ! defined $user_id;

    my %user_content          = ();
    my @data                  = ();
    my @content_types         = ();
    my @image_categories      = ();
    my @image_values          = ();
    my @image_percents        = ();
    my @music_categories      = ();
    my @music_values          = ();
    my @literature_categories = ();
    my @literature_values     = ();

    my $dbh = $DB->dbh();
    my $user = Side7::User::get_user_by_id( $user_id );

    # Get Images Breakdown
    my $sql = build_select(
                                db       => $DB,
                                dbh      => $dbh,
                                select   => 'COUNT( 1 ) as num_images, category',
                                tables   => [ 'images', 'categories' ],
                                classes  => {
                                                images     => 'Side7::UserContent::Image',
                                                categories => 'Side7::UserContent::Category',
                                            },
                                columns  => {
                                                images     => [],
                                                categories => [ qw( category ) ],
                                            },
                                query    => [
                                                user_id => $user_id,
                                            ],
                                clauses  => [ 't1.category_id = t2.id' ],
                                group_by => 'category',
                          );

    #$LOGGER->debug( "SQL: $sql" );

    my $sth = $dbh->prepare( $sql );
    $sth->execute();

    if ( $sth->rows() > 0 )
    {
        push( @content_types, "'Images'" );
    }

    my $total = $user->get_image_count();
    while ( my $row = $sth->fetchrow_hashref )
    {
        push( @image_categories, "'$row->{'category'}'" );
        push( @image_values, $row->{'num_images'} );
    }

    if ( scalar( @image_categories ) > 0 )
    {
        push( @data, {
                        value                => $user->get_image_count(),
                        drilldown_name       => 'Image Categories',
                        drilldown_categories => join( ',', @image_categories ),
                        drilldown_values     => join( ',', @image_values ),
                     }
        );
    }

    # Get Music Breakdown
    push( @content_types, "'Music'" );
    push( @data, {
                    value                => 15,
                    drilldown_name       => 'Music Categories',
                    drilldown_categories => "'Rock','Electronic','Jazz','Vocal'",
                    drilldown_values     => '2,6,4,3',
                 }
    );

    # Get Literature Breakdown
    push( @content_types, "'Literature'" );
    push( @data, {
                    value                => 25,
                    drilldown_name       => 'Literature Categories',
                    drilldown_categories => "'Science Fiction','Horror','Non-fiction'",
                    drilldown_values     => '14,7,4',
                 }
    );

    $user_content{'categories'} = join( ',', @content_types );
    $user_content{'data'} = \@data;

    #$LOGGER->debug( 'USER_CONTENT: ' . Dumper( \%user_content ) );

    return \%user_content;
}


=head2 get_user_disk_usage_stats()

Return a hashref of disk quota and usage values for use with Highcharts gauges. Returned values are in bytes.

Parameters:

=over 4

=item user: The User object for which to obtain disk usage data.

=back

    my $disk_usage_data = Side7::Report->get_user_disk_usage_stats( $user );

=cut

sub get_user_disk_usage_stats
{
    my ( $self, $user ) = @_;

    my $disk_stats = {};

    my $disk_usage = 0;
    my $disk_quota = 0;
    if ( defined $user->{'account'} && defined $user->account->user_role->name() )
    {
        # Disk Quota
        $disk_usage = Side7::Utils::File::get_disk_usage( filepath => $user->get_content_directory() ) // 0;

        if ( $user->account->user_role->has_perk( 'disk_quota_unlimited' ) )
        {
            $disk_quota = 1073741824; # 1GB in bytes
        }
        elsif
        (
            defined $user->{'user_owned_perks'}
        )
        {
            foreach my $perk ( @{ $user->user_owned_perks } )
            {
                if (
                        $perk->perk->name() eq 'disk_quota_500'
                        &&
                        $perk->perk->suspended != 1
                        &&
                        $perk->perk->revoked != 1
                )
                {
                    $disk_quota = 524288000; # 500MB in bytes
                }
            }
        }
        else
        {
            $disk_quota = 209715200; # 200MB in bytes
        }
    }

    $disk_stats->{'disk_quota'} = $disk_quota;
    $disk_stats->{'disk_usage'} = $disk_usage;

    return $disk_stats;
}


=head1 FUNCTIONS


=head2 function_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package::function_name();

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
