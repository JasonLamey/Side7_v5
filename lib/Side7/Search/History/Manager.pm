package Side7::Search::History::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::Search::History::Manager

=head1 DESCRIPTION

Creates a DB Object manager for multiple records.

=head1 SCHEMA INFORMATION

    See Side7::Search::History.

=head1 RELATIONSHIPS

    See Side7::Search::History.

=cut

=head1 METHODS

=head2 make_manager_methods('object');

    $result = Side7::Search::History::Manager->make_manager_methods();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub object_class { 'Side7::Search::History' }

__PACKAGE__->make_manager_methods('searches');

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
