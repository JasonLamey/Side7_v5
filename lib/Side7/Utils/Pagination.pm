package Side7::Utils::Pagination;

use strict;
use warnings;

use Side7::Globals;


=head1 NAME

Side7::Utils::Pagination;


=head1 DESCRIPTION

Supplies tools and functionality for generating necessary data for pagination menus.


=head1 FUNCTIONS

=head2 get_pagination()

    $pagination = Side7::Utils::Pagination::get_pagination( { 
                                    total_count => $total, 
                                    page => $page,
                                    pagination_limit => $pagination_limit 
                            } );

Returns a hashref of pagination variables, including previous page number, next page number, total count,
first item, last item, total pages.  C<pagination_limit> is optional, and defaults to the configured amount.

=cut

sub get_pagination
{
    my ( $args ) = @_;

    my $total_count      = delete $args->{'total_count'}      // 1;
    my $page             = delete $args->{'page'}             // 1;
    my $pagination_limit = delete $args->{'pagination_limit'} // 
                                    $CONFIG->{'page'}->{'user_directory'}->{'pagination_limit'};

    # In the event a blank but defined parameter is passed in.
    if ( $total_count eq '' )
    {
        $total_count = 1;
    }
    if ( $page eq '' )
    {
        $page = 1;
    }

    my $last_page = ( $total_count % $pagination_limit == 0 )
                  ? ( $total_count / $pagination_limit )
                  : ( int( $total_count / $pagination_limit ) ) + 1;

    my $next_page     = ( $page != $last_page ) ? ( $page + 1 ) : undef;
    my $previous_page = ( $page != 1 )          ? ( $page - 1 ) : undef;

    my $first_item = ( ( ( $page - 1 ) * $pagination_limit ) + 1 );
    my $last_item  = ( $page == $last_page ) ? $total_count : ( $first_item + ( $pagination_limit - 1 ) );

    my $pagination = {
        first_item    => $first_item,
        last_item     => $last_item,
        total_count   => $total_count,
        next_page     => $next_page,
        previous_page => $previous_page,
        total_pages   => $last_page,
        current_page  => $page,
    };

    return $pagination;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
