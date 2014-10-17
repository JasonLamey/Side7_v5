package Side7::DB::Object;

use strict;
use warnings;

use Side7::DB;

use base qw(Rose::DB::Object);

use version; our $VERSION = qv( '0.1.1' );

=pod

=head1 NAME

Side7::DB::Object

=head1 DESCRIPTION

This class handles the database objects derived from Side7::DB.
It inherits from Rose::DB::Object.

=cut

sub init_db
{
    Side7::DB->new;
}

=pod

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2013

=cut

1;
