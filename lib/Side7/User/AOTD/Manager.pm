package Side7::User::AOTD::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::User::AOTD::Manager

=head1 DESCRIPTION

Creates a DB Object manager for multiple records.

=head1 SCHEMA INFORMATION

    See Side7::User::AOTD.

=head1 RELATIONSHIPS

    See Side7::User::AOTD.

=cut

=head1 METHODS

=head2 make_manager_methods('object');

    $result = Side7::User::AOTD::Manager->make_manager_methods();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub object_class { 'Side7::User::AOTD' }

__PACKAGE__->make_manager_methods('aotds');

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
