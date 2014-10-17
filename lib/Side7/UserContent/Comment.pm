package Side7::UserContent::Comment;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.1' );


=head1 NAME

Side7::UserContent::Comment


=head1 DESCRIPTION

This package represents a comment that a User would leave on User uploaded content.


=head1 SCHEMA INFORMATION

    Table name: comments

    | id                | bigint(20) unsigned                   | NO   | PRI | NULL    | auto_increment |
    | comment_thread_id | bigint(20) unsigned                   | NO   | MUL | NULL    |                |
    | user_id           | bigint(20) unsigned                   | YES  |     | NULL    |                |
    | anonymous_name    | varchar(100)                          | YES  |     | NULL    |                |
    | comment           | text                                  | NO   |     | NULL    |                |
    | private           | tinyint(1)                            | NO   |     | 0       |                |
    | award             | enum('none','bronze','silver','gold') | NO   |     | none    |                |
    | owner_rating      | smallint(5) unsigned                  | NO   |     | NULL    |                |
    | ip_address        | varchar(100)                          | YES  |     | NULL    |                |
    | created_at        | datetime                              | NO   |     | NULL    |                |
    | updated_at        | datetime                              | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::UserContent::CommentThread

Many-to-one relationship; FK is comment_thread_id.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'comments',
    columns => [
        id                => { type => 'integer', not_null => 1 },
        comment_thread_id => { type => 'integer', not_null => 1 },
        user_id           => { type => 'integer' },
        anonymous_name    => { type => 'varchar', length => 100 },
        comment           => { type => 'text',    not_null => 1 },
        private           => { type => 'integer', length => 1,  not_null => 1, default => 0 },
        award             => {
                                type     => 'enum',
                                values   => [ 'none', 'bronze', 'silver', 'gold' ],
                                not_null => 1,
                                default  => 'none',
                             },
        owner_rating      => { type => 'integer' },
        ip_address        => { type => 'varchar', length => 100 },
        created_at        => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at        => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [
                    [ 'comment_thread_id' ],
                  ],
    foreign_keys =>
    [
        comment_thread =>
        {
            class      => 'Side7::UserContent::CommentThread',
            column_map => { comment_thread_id => 'id' },
        },
        user =>
        {
            class => 'Side7::User',
            column_map => { user_id => 'id' },
        },
    ],
);


=head1 METHODS


=head2 method_name()

    my $result = My::Package->method_name();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub method_name
{
}


=head1 FUNCTIONS


=head2 function_name()

    my $result = My::Package::function_name();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
