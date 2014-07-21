package Side7::Account::Friend
use Mojo::Base 'Mojolicious::Controller';

use MojoX::Validator;

# == Schema Information
#
# Table name: friends
#
#  id         :integer          not null, primary key
#  account_id :integer          not null
#  friend_id  :integer          not null
#  approved   :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

=pod

=head1 NAME

Side7::Account::Friend

=head1 DESCRIPTION

This class represents a bi-directional relationship between two accounts.
One side must initiate the relationship, creating an unapproved, one-way
relationship.  When approved by the recipient, the original relationship is
approved, and a subsequent, approved relationship in the opposite direction is
established.

=head1 METHODS

=cut

sub new
{
    my ($self, %args) = @_;

    bless {}, shift;
}

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2013

=cut

1;
