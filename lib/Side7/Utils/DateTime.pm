package Side7::Utils::DateTime;

use strict;
use warnings;

use Side7::Globals;

use DateTime;
use POSIX;

use version; our $VERSION = qv( '0.1.1' );


=head1 NAME

Side7::Utils::DateTime;


=head1 DESCRIPTION

Supplies tools and functionality for managing special Date/Time modifications.


=head1 METHODS


=head2 get_english_elapsed_time()

Returns a C<string> stating the amount of time that has elapsed since the passed-in datetime.
The returned C<string> is generalized in the following ways:

=over 4

=item < 5: "Just now."

=item < 10 >= 5: "A few seconds ago."

=item < 60 >= 10: "Less than a minute ago."

=item < 3600 >= 60: "X minutes ago."

=item < 86400 >= 3600: "X hours ago."

=item < 604800 >= 86400: "X days ago."

=item < 2592000 >= 604800: "X weeks ago."

=item < 31536000 >= 2592000: "X months ago."

=item >= 31536000: "X years ago."

=back

Parameters:

=over 4

=item seconds: The timestamp in seconds.  Mandatory.

=back

    my $english_elapsed = Side7::Utils::DateTime->get_english_elapsed_time( seconds => $seconds );

=cut

sub get_english_elapsed_time
{
    my ( $self, %args ) = @_;

    my $seconds = delete $args{'seconds'} // undef;

    if ( ! defined $seconds || $seconds !~ m/^\d+$/ )
    {
        $LOGGER->warn( 'Invalid seconds value >' . $seconds . '< passed in.' );
        return 'I don\'t know...';
    }

    my $epoch_now = DateTime->now()->epoch();

    my $elapsed_seconds = POSIX::ceil( $epoch_now - $seconds );

    if (    $elapsed_seconds >= 0       && $elapsed_seconds < 5 )
    {
        return 'Just now.';
    }
    elsif ( $elapsed_seconds >= 5       && $elapsed_seconds < 10 )
    {
        return 'A few seconds ago.';
    }
    elsif ( $elapsed_seconds >= 10      && $elapsed_seconds < 60 )
    {
        return 'Less than a minute ago.';
    }
    elsif ( $elapsed_seconds >= 60      && $elapsed_seconds < 3600 )
    {
        my $minutes = POSIX::floor( $elapsed_seconds / 60 );
        return sprintf( 'About %d %s ago.', $minutes, ( $minutes == 1 ) ? 'minute' : 'minutes' );
    }
    elsif ( $elapsed_seconds >= 3600    && $elapsed_seconds < 86400 )
    {
        my $hours = POSIX::floor( $elapsed_seconds / 3600 );
        return sprintf( 'About %d %s ago.', $hours, ( $hours == 1 ) ? 'hour' : 'hours' );
    }
    elsif ( $elapsed_seconds >= 86400   && $elapsed_seconds < 604800 )
    {
        my $days = POSIX::floor( $elapsed_seconds / 86400 );
        return sprintf( 'About %d %s ago.', $days, ( $days == 1 ) ? 'day' : 'days' );
    }
    elsif ( $elapsed_seconds >= 604800  && $elapsed_seconds < 2592000 )
    {
        my $weeks = POSIX::floor( $elapsed_seconds / 604800 );
        return sprintf( 'About %d %s ago.', $weeks, ( $weeks == 1 ) ? 'week' : 'weeks' );
    }
    elsif ( $elapsed_seconds >= 2592000 && $elapsed_seconds < 31536000 )
    {
        my $months = POSIX::floor( $elapsed_seconds / 2592000 );
        return sprintf( 'About %d %s ago.', $months, ( $months == 1 ) ? 'month' : 'months' );
    }
    elsif ( $elapsed_seconds >= 31536000 )
    {
        my $years = POSIX::floor( $elapsed_seconds / 31536000 );
        return sprintf( 'About %d %s ago.', $years, ( $years == 1 ) ? 'year' : 'years' );
    }
    else
    {
        return 'Timey-wimey confusion here...';
    }
}


=head1 FUNCTIONS


=head2 get_pagination()

    $pagination = Side7::Utils::DateTime::get_pagination( {
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
                                    $CONFIG->{'page'}->{'default'}->{'pagination_limit'};

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
