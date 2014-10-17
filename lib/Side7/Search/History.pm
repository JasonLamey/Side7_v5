package Side7::Search::History;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.1' );

=pod

=head1 NAME

Side7::Search::History

=head1 DESCRIPTION

Storage of all search requests for quick-retrieval if necessary, as well as reporting.

=head1 SCHEMA INFORMATION

    Table name: search_history

    | id           | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | search_term  | varchar(255)        | NO   | MUL | NULL    |                |
    | timestamp    | datetime            | NO   | MUL | NULL    |                |
    | user_id      | bigint(20) unsigned | YES  | MUL | NULL    |                |
    | ip_address   | varchar(255)        | YES  | MUL | NULL    |                |
    | results      | longtext            | YES  |     | NULL    |                |
    | search_count | int(10) unsigned    | NO   |     | 1       |                |

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'search_history',
    columns => [
        id            => { type => 'serial',   not_null => 1 },
        search_term   => { type => 'varchar', length => 255, not_null => 1 },
        timestamp     => { type => 'datetime', not_null => 1, default => 'now()' },
        user_id       => { type => 'integer' },
        ip_address    => { type => 'varchar', length => 255 },
        results       => { type => 'text' },
        search_count  => { type => 'integer',  not_null => 1, default => 1 },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'search_term', 'timestamp' ], [ 'search_term' ], [ 'timestamp' ], [ 'user_id' ], [ 'ip_address' ], ],
);

=head1 METHODS


=head2 method_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package->method_name();

=cut

sub method_name
{
}


=head1 FUNCTIONS


=head2 function_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package::function_name();

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
