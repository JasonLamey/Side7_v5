package Side7::Account::Manager;

use strict;
use warnings;

use base 'Rose::DB::Object::Manager';

=pod

=head1 NAME

Side7::Account::Manager

=head1 DESCRIPTION

This class creates the necessary object manager methods.

=cut

sub object_class { 'Side7::Account' }

__PACKAGE__->make_manager_methods('accounts');

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2013

=cut

1;
