package Side7::User::Type;

use strict;
use warnings;

use base 'Side7::DB::Object';
use Mojo::Base 'Mojolicious::Controller';

# == Schema Information
#
# Table name: user_types
#
#  id         :integer          not null, primary key
#  user_type  :string(255)
#

__PACKAGE__->meta->setup
(
    table   => 'user_types',
    columns => [ 
        id            => { type => 'integer', not_null => 1 },
        user_type     => { type => 'varchar', length => 45,  not_null => 1 }, 
    ],
    pk_columns => 'id',
    unique_key => 'user_type',
);

=pod

=head1 NAME

Side7::User::Type

=head1 DESCRIPTION

This class represents a type of user - Basic, Premiere, Ultimate.
These types determine account permissions and access.

=head1 METHODS

=head2 new()

    my $user = Side7::User::Type->new( 
        user_type      => $type, 
    );

=over

=item Returns a new Type object.

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
