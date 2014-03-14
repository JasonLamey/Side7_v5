package Side7::DateVisibility;

use strict;
use warnings;

use base 'Side7::DB::Object';
use Mojo::Base 'Mojolicious::Controller';

use Side7::Account;

# == Schema Information
#
# Table name: date_visibilities
#
#  id              :integer          not null, primary key
#  visibility      :string(45)
#

__PACKAGE__->meta->setup
(
    table   => 'date_visibilities',
    columns => [ 
        id            => { type => 'integer', not_null => 1 },
        visibility    => { type => 'varchar', length => 45,  not_null => 1 }, 
    ],
    pk_columns => 'id',
    unique_key => 'visibility',
    relationships =>
    [
        account =>
        {
            type       => 'one to one',
            class      => 'Side7::Account',
            column_map => { id => 'birthday_visibility' },
        },
    ],
);

=pod

=head1 NAME

Side7::DateVisibility

=head1 DESCRIPTION

This class represents a visibility settings for a date, specifically birthdates.
Possible settings are Full, Hide Year, and Hidden

=head1 METHODS

=head2 new()

    my $user = Side7::DateVisibility->new( 
        visibilty => $visibility, 
    );

=over

=item Returns a new DateVisibility object.

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
