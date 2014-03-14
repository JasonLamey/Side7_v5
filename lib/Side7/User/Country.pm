package Side7::User::Country;

use strict;
use warnings;

use base 'Side7::DB::Object';
use Mojo::Base 'Mojolicious::Controller';

# == Schema Information
#
# Table name: countries
#
#  id         :integer          not null, primary key
#  name       :string(45)       not null
#  code       :string(3)        not null
#

__PACKAGE__->meta->setup
(
    table   => 'countries',
    columns => [ 
        id            => { type => 'integer', not_null => 1 },
        name          => { type => 'varchar', length => 45,  not_null => 1 }, 
        code          => { type => 'varchar', length => 3,   not_null => 1 }, 
    ],
    pk_columns => 'id',
    unique_key => [ 'name', 'code' ],
);

=pod

=head1 NAME

Side7::User::Country

=head1 DESCRIPTION

This class represents a country associated to an account.

=head1 METHODS

=head2 new()

    my $country = Side7::User::Country->new( 
        name      => $name, 
        code      => $code, 
    );

=over

=item Returns a new Country object.

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
