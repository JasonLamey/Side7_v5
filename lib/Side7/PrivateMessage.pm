package Side7::PrivateMessage;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.0' );


=head1 NAME

Side7::PrivateMessage


=head1 DESCRIPTION

Gives access to write and read Private Messages sent from one User to another.

=head1 SCHEMA INFORMATION

    Table name: private_messages

    | id           | bigint(20) unsigned                   | NO   | PRI | NULL      | auto_increment |
    | sender_id    | bigint(20) unsigned                   | NO   |     | NULL      |                |
    | recipient_id | bigint(20) unsigned                   | NO   |     | NULL      |                |
    | subject      | varchar(255)                          | YES  |     | NULL      |                |
    | body         | text                                  | NO   |     | NULL      |                |
    | status       | enum('Delivered','Read','Replied To') | NO   |     | Delivered |                |
    | created_at   | datetime                              | NO   |     | NULL      |                |
    | read_at      | datetime                              | YES  |     | NULL      |                |
    | replied_at   | datetime                              | YES  |     | NULL      |                |
    | deleted_at   | datetime                              | YES  |     | NULL      |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

Foreign Key: sender_id => id, one-to-one

=item Side7::User

Foreign Key: recipient_id => id, one-to-one

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'private_messages',
    columns => [
        id           => { type => 'serial',  not_null => 1 },
        sender_id    => { type => 'integer', not_null => 1 },
        recipient_id => { type => 'integer', not_null => 1 },
        subject      => { type => 'varchar', length   => 255 },
        body         => { type => 'text',    not_null => 1 },
        status       => {
                            type     => 'enum',
                            values   => [ 'Delivered', 'Read', 'Replied To', 'Deleted' ],
                            not_null => 1,
                            default  => 'Delivered',
                        },
        created_at   => { type => 'datetime', not_null => 1, default => 'now()' },
        read_at      => { type => 'datetime' },
        replied_at   => { type => 'datetime' },
        deleted_at   => { type => 'datetime' },
    ],
    pk_columns => 'id',
    foreign_keys =>
    [
        sender =>
        {
            class             => 'Side7::User',
            key_columns       => { sender_id => 'id' },
            relationship_type => 'one to one',
        },
        recipient =>
        {
            class             => 'Side7::User',
            key_columns       => { recipient_id => 'id' },
            relationship_type => 'one to one',
        },
    ],
);

=head1 METHODS


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
