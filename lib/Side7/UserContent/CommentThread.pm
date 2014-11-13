package Side7::UserContent::CommentThread;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;
use Side7::UserContent::CommentThread::Manager;

use version; our $VERSION = qv( '0.1.2' );


=pod


=head1 NAME

Side7::UserContent::CommentThread


=head1 DESCRIPTION

This package represents comment threads on User uploaded content.


=head1 SCHEMA INFORMATION

    Table name: comment_threads

    | id            | bigint(20) unsigned                        | NO   | PRI | NULL    | auto_increment |
    | content_id    | bigint(20) unsigned                        | NO   | MUL | NULL    |                |
    | content_type  | enum('Image','Literature','Music','Video') | NO   |     | NULL    |                |
    | thread_status | enum('Open','Closed     ')                 | NO   |     | open    |                |
    | created_at    | datetime                                   | NO   |     | NULL    |                |
    | updated_at    | datetime                                   | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Image

Many-to-one.  Foreign key is content_id, which links to images.id.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'comment_threads',
    columns => [
        id            => { type => 'integer', not_null => 1 },
        content_id    => { type => 'integer', not_null => 1 },
        content_type  => {
                            type     => 'enum',
                            values   => [ 'Image', 'Literature', 'Music', 'Video' ],
                            not_null => 1,
                         },
        thread_status => {
                            type     => 'enum',
                            values   => [ 'Open', 'Closed' ],
                            default  => 'Open',
                            not_null => 1,
                         },
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [
                    [ 'id', 'content_id', 'content_type', 'thread_status' ],
                    [ 'content_id', 'content_type', 'thread_status' ],
                    [ 'content_id', 'content_type' ],
                    [ 'content_id' ],
                  ],
    foreign_keys =>
    [
        image =>
        {
            class      => 'Side7::UserContent::Image',
            column_map => { content_id => 'id' },
        },
    ],
    relationships =>
    [
        comments =>
        {
            type       => 'one to many',
            class      => 'Side7::UserContent::Comment',
            column_map => { id => 'comment_thread_id' },
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


=head2 get_all_comments_for_content()

    my $comment_threads = Side7::UserContent::CommentThread::get_all_comments_for_content();

Fetches all comment threads related to a particular User Content item, along with all comments associated to each thread.
Takes two arguments: content_type and content_id.  Returns an arrayref of threads and their associated comments.

=cut

sub get_all_comments_for_content
{
    my ( %args ) = @_;

    my $content_type = delete $args{'content_type'};
    my $content_id   = delete $args{'content_id'};

    return [] if ( ! defined $content_type && ! defined $content_id );

    if (
        $content_type ne 'Image'
        &&
        $content_type ne 'Literature'
        &&
        $content_type ne 'Music'
        &&
        $content_type ne 'Video'
    )
    {
        $LOGGER->warn( 'Invalid content_type >' . $content_type . '< passed in.' );
        return [];
    }

    my $comment_threads = Side7::UserContent::CommentThread::Manager->get_comment_threads(
                                query => [
                                    content_type => $content_type,
                                    content_id   => $content_id,
                                ],
                                sort_by      => 'created_at ASC',
                                with_objects => [ 'comments' ],
                            );

    if ( ! defined $comment_threads )
    {
        return [];
    }

    return $comment_threads;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
