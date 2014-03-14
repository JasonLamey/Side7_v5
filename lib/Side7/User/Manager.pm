package Side7::User::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager'; # Only needed if this is a database object.
use Mojo::Base 'Mojolicious::Controller';

=pod

=head1 NAME

Side7::User::Manager

=head1 DESCRIPTION

Creates a DB Object manager for multiple records.

=head1 SCHEMA INFORMATION

    See Side7::User.

=head1 RELATIONSHIPS

    See Side7::User.

=cut

=head1 METHODS

=head2 make_manager_methods('object');

    $result = Side7::User::Manager->make_manager_methods();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub object_class { 'User' }

__PACKAGE__->make_manager_methods('users');

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
