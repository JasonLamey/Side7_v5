package Side7::UserContent::Image::Property::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::UserContent::Image::Property::Manager

=head1 DESCRIPTION

Creates a DB Object manager for multiple records.

=head1 SCHEMA INFORMATION

    See Side7::UserContent::Image::Property.

=head1 RELATIONSHIPS

    See Side7::UserContent::Image::Property.

=cut

=head1 METHODS

=head2 make_manager_methods('object');

    $result = Side7::UserContent::Image::Property::Manager->make_manager_methods();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub object_class { 'Side7::UserContent::Image::Property' }

__PACKAGE__->make_manager_methods('properties');

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
