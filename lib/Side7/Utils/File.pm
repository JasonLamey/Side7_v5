package Side7::Utils::File;

use strict;
use warnings;

use Side7::Globals;


=head1 NAME

Side7::Utils::File


=head1 DESCRIPTION

Provides file and file attribute-related tools


=head1 FUNCTIONS


=head2 get_formatted_filesize_from_bytes()

    $filesize = Side7::Utils::File::get_formatted_filesize_from_bytes( $filesize_in_bytes );

Returns a formatted string from the value passed in.  Value is assumed to be in bytes.

=cut

sub get_formatted_filesize_from_bytes
{
    my ( $size_in_bytes ) = @_;

    my $exp = 0;

    my $units = [ qw( B KB MB GB TB PB ) ];

    foreach my $unit ( @$units ) {
        last if $size_in_bytes < 1024;
        $size_in_bytes /= 1024;
        $exp++;
    }

    return wantarray ? ( $size_in_bytes, $units->[$exp] ) : sprintf( "%d %s", $size_in_bytes, $units->[$exp] );
}


=head2 create_user_directory

    my $success = Side7::Utils::File::create_user_directory( $user->id );

Creates the file structure for a new User account.  Returns a boolean for success, and any error messages.

=cut

sub create_user_directory
{
    my ( $user_id ) = @_;

    return ( 0, 'Invalid User credentials' ) if ! defined $user_id || $user_id !~ m/^\d+$/;

    my $tier1 = substr( $user_id, 0, 1 );
    my $tier2 = substr( $user_id, 0, 3 );

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 )
    {
        mkdir $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 || return ( 0, $! );
    }

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 )
    {
        mkdir $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 || return ( 0, $! );
    }

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 . '/' . $user_id )
    {
        mkdir $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 . '/' . $user_id || return ( 0, $! );
    }

    return ( 1, undef );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
