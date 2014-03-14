package Side7::User::Status;

use strict;
use warnings;

use base 'Side7::DB::Object';
use Mojo::Base 'Mojolicious::Controller';

# == Schema Information
#
# Table name: user_types
#
#  id          :integer          not null, primary key
#  user_status :string(45)
#

__PACKAGE__->meta->setup
(
    table   => 'user_statuses',
    columns => [ 
        id            => { type => 'integer', not_null => 1 },
        user_status   => { type => 'varchar', length => 45,  not_null => 1 }, 
    ],
    pk_columns => 'id',
    unique_key => 'user_status',
);

=pod

=head1 NAME

Side7::User::Status

=head1 DESCRIPTION

This class represents a status of user account - Pending, Active, Suspended, and Disabled.
These statuses determine if an account can access the site.

=head1 METHODS

=head2 new()

    my $user = Side7::User::Status->new( 
        user_status    => $status, 
    );

=over

=item Returns a new Status object.

=back

=cut

#sub new
#{
#    my $class = @_;
#
#    my $self = {};
#
#    bless $self, $class;
#    return $self;
#}

=pod

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2013

=cut

1;
