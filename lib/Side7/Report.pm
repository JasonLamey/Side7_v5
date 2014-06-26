package Side7::Report;

use strict;
use warnings;

use Rose::DB::Object::QueryBuilder qw( build_select );

use Data::Dumper;

use Side7::Globals;


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

    $LOGGER->debug( "SQL: $sql" );

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

    # Get Literature Breakdown

    $user_content{'categories'} = join( ',', @content_types );
    $user_content{'data'} = \@data;

    $LOGGER->debug( 'USER_CONTENT: ' . Dumper( \%user_content ) );

    return \%user_content;
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
