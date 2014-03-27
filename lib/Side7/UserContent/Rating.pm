package Side7::UserContent::Rating;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::UserContent::Rating

=head1 DESCRIPTION

This package represents the possible ratings User Content can have.

=head1 SCHEMA INFORMATION

    Table name: ratings

    id                 :integer          not null, primary key
    rating             :string(255)
    requires_qualifier :string(255)
    priority           :integer
    content_type       :enum             ('Image','Literature','Music','Video')
    created_at         :datetime         not null
    updated_at         :datetime         not null


=head1 RELATIONSHIPS

=over

=item Class::Name

TODO: Define the relationship type, and list the foreign key (FK).

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'ratings',
    columns => [ 
        id                 => { type => 'integer', not_null => 1 },
        rating             => { type => 'varchar', length => 255, not_null => 1 }, 
        requires_qualifier => { type => 'tinyint', length => 1,   not_null => 1 }, 
        priority           => { type => 'integer', length => 5,   not_null => 1 }, 
        content_type       => { 
                                type    => 'enum',
                                values  => [ qw/Image Literature Music Video/ ],
                                default => 'Image',
        }, 
        created_at         => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at         => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'content_type' ],
);

=head1 METHODS

=head2 method_name

    $result = My::Package->method_name();

TODO: Define what this method does, describing both input and output values and types.

=cut

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
