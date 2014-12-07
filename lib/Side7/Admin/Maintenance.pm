package Side7::Admin::Maintenance;

use strict;
use warnings;

use File::Path;
use List::Util;
use Data::Dumper;

use Side7::Globals;
use Side7::DB;
use Side7::AuditLog::Manager;
use Side7::User;

use version; our $VERSION = qv( '0.1.0' );

=pod


=head1 NAME

Side7::Admin::Maintenance


=head1 DESCRIPTION

Maintenance methods for dealing with Administrative tasks.


=head1 METHODS


=head2 flush_cached_files( $cache_type )

Deletes cached files associated with the C<$cache_type> indicated. Returns a hashref
containing a success C<boolean> and an error string;

Parameters:

=over 4

=item cache_type: the type of cache to delete. Accepts: [ 'image', 'avatar' ]

=back

    my $result_hash = Side7::Admin::Maintenance->flush_cached_files( $cache_type );

=cut

sub flush_cached_files
{
    my ( $self, $cache_type ) = @_;

    return { success => 0, num_removed => 0, error => 'Invalid cache type.' } if ! defined $cache_type;

    my $path = undef;
    if ( List::Util::any { $cache_type eq $_ } [ qw/ avatars images / ] )
    {
        $path = $CONFIG->{'app_dir'} . '/public/cached_files/user_content/' . lc( $cache_type );
    }
    else
    {
        $path = $CONFIG->{'app_dir'} . '/public/cached_files/templates';
    }
    $LOGGER->debug( 'FLUSH PATH: >' . $path . '<' );
    my $removed = undef;
    my $error   = undef;
    my $num_removed = File::Path::remove_tree(
                                                $path,
                                                {
                                                    keep_root => 1,
                                                    result    => \$removed,
                                                    error     => \$error,
                                                }
    );
    my $error_msg = undef;
    if ( @{ $error } )
    {
        foreach my $diag ( @{ $error } )
        {
            my ( $file, $message ) = %{ $diag };
            if ( $file eq '' )
            {
                $error_msg .= 'General error: ' . $message . "\n";
            }
            else
            {
                $error_msg .= 'Problem unlinking cache file >' . $file . '<: ' . $message . "\n";
            }
        }
    }

    if ( $error_msg )
    {
        $LOGGER->error( ucfirst( $cache_type ) . ' Flush Cache Error: ' . $error_msg . ': Removed: ' . join( '; ', @{ $removed } ) );
        return { success => 0, num_removed => $num_removed,
                    error => 'Some or all of the files could not be deleted. See system logs for more details.' };
    }
    else
    {
        $LOGGER->info( ucfirst( $cache_type ) . ' Flush Cache Results: ' . $num_removed . ' removed: ' . join( '; ', @{ $removed } ) );
        return { success => 1, num_removed => $num_removed, error => undef };
    }
}


=head2 flush_cached_files_for_user( $user_obj, $cache_type )

Removes the cached files for a particular User, or an arrayref of Users.  Returns a hashref of success boolean,
num_removed counter, and error message.

Parameters:

=over 4

=item user_obj: The User object, or an C<arrayref> of User objects, to delete cache for. Mandatory.

=item $cache_type: The type of cache to clear out.  Mandatory.

=back

    my $results = Side7::Admin::Maintenance->flush_cached_files_for_user( $users, $cache_type );

=cut

sub flush_cached_files_for_user
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
