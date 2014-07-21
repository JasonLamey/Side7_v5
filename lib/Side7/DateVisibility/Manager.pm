package Side7::DateVisibility::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager';

=pod

=head1 NAME

Side7::DateVisibility::Manager

=head1 DESCRIPTION

This class creates the necessary object manager methods.

=cut

sub object_class { 'Side7::DateVisibility' }

__PACKAGE__->make_manager_methods('date_visibilities');

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2014

=cut

1;
