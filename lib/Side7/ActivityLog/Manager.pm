package Side7::ActivityLog::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::ActivityLog::Manager

=head1 DESCRIPTION

Creates a DB Object manager for multiple records.

=head1 SCHEMA INFORMATION

    See Side7::ActivityLog.

=head1 RELATIONSHIPS

    See Side7::ActivityLog.

=cut

=head1 METHODS

=head2 make_manager_methods('object');

    $result = Side7::ActivityLog::Manager->make_manager_methods();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub object_class { 'Side7::ActivityLog' }

__PACKAGE__->make_manager_methods('activity_logs');

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
