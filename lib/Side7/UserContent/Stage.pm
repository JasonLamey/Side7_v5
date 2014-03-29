package Side7::UserContent::Stage;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::UserContent::Stage

=head1 DESCRIPTION

This package represents a content's current stage of progress.

=head1 SCHEMA INFORMATION

    Table name: stages

    | id         | int(1) unsigned | NO   | PRI | NULL    | auto_increment |
    | stage      | varchar(45)     | NO   |     | NULL    |                |
    | priority   | int(1)          | NO   | MUL | NULL    |                |
    | created_at | datetime        | NO   |     | NULL    |                |
    | updated_at | datetime        | NO   |     | NULL    |                |

=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Image

Stage is a lookup object referenced by Image using C<stage_id> to reference C<id>.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'stages',
    columns => [ 
        id            => { type => 'integer', length => 1,   not_null => 1 },
        stage         => { type => 'varchar', length => 45,  not_null => 1 }, 
        priority      => { type => 'integer', length => 1,   not_null => 1 }, 
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'stage', 'priority' ],
    relationships =>
    [
        image =>
        {
            type       => 'one to many',
            class      => 'Side7::UserContent::Image',
            column_map => { id => 'stage_id' },
        },
    ],
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
