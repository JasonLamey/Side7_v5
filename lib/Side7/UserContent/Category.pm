package Side7::UserContent::Category;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;
use Side7::UserContent::Category::Manager;

=pod

=head1 NAME

Side7::UserContent::Category

=head1 DESCRIPTION

This package represents User Content categories for content to be tagged with.

=head1 SCHEMA INFORMATION

    Table name: categories

    | id           | int(5) unsigned | NO   | PRI | NULL    | auto_increment |
    | category     | varchar(255)    | NO   |     | NULL    |                |
    | priority     | int(5) unsigned | NO   | MUL | NULL    |                |
    | content_type | varchar(255)    | NO   |     | NULL    |                |
    | created_at   | datetime        | NO   |     | NULL    |                |
    | updated_at   | datetime        | NO   |     | NULL    |                |

=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Image

Called by Image, using C<category_id> as the FK in Image linking to the C<id> field.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'categories',
    columns => [ 
        id            => { type => 'integer', length => 5,   not_null => 1 },
        category      => { type => 'varchar', length => 255, not_null => 1 }, 
        priority      => { type => 'integer', length => 5,   not_null => 1 }, 
        content_type  => { type => 'varchar', length => 255, not_null => 1 }, 
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'category', 'content_type' ],
    relationships =>
    [
        image =>
        {
            type       => 'one to many',
            class      => 'Side7::UserContent::Image',
            column_map => { id => 'category_id' },
        },
    ],
);


=head1 METHODS


=head2 get_categories_for_form()

Returns an array ref of keys and values for categories, depending upon the content type provided.

Parameters:

=over 4

=item content_type: The Content type to filter on. Accepts 'image', 'music', or 'literature'.

=back

    my $categories = Side7::UserContent::Category->get_categories_for_form( content_type => $content_type );

=cut

sub get_categories_for_form
{
    my ( $self, %args ) = @_;

    my $content_type = delete $args{'content_type'} // undef;

    return [] if ! defined $content_type;

    my $categories = Side7::UserContent::Category::Manager->get_categories(
        query =>
        [
            content_type => $content_type,
        ],
        sort_by => 'priority ASC',
    );

    my @results = ();
    foreach my $category ( @{ $categories } )
    {
        push( @results, { id => $category->id(), category => $category->category() } );
    }

    return \@results;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
