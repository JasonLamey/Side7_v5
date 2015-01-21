package Side7::UserContent::Rating;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;
use Side7::UserContent::Rating::Manager;

use version; our $VERSION = qv( '0.1.2' );

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
    relationships => [
        images => {
            type       => 'one to many',
            class      => 'Side7::UserContent::Image',
            column_map => { id => 'rating_id' },
        },
        music => {
            type       => 'one to many',
            class      => 'Side7::UserContent::Music',
            column_map => { id => 'rating_id' },
        },
    ],
);


=head1 METHODS


=head2 get_ratings_for_form()

Returns an array ref of keys and values for ratings, depending upon the content type provided.

Parameters:

=over 4

=item content_type: The Content type to filter on. Accepts 'image', 'music', or 'literature'.

=back

    my $ratings = Side7::UserContent::Rating->get_ratings_for_form( content_type => $content_type );

=cut

sub get_ratings_for_form
{
    my ( $self, %args ) = @_;

    my $content_type = delete $args{'content_type'} // undef;

    return [] if ! defined $content_type;

    my $ratings = Side7::UserContent::Rating::Manager->get_ratings(
        query =>
        [
            content_type => $content_type,
        ],
        sort_by => 'priority ASC',
    );

    my @results = ();
    foreach my $rating ( @{ $ratings } )
    {
        push( @results, {
                            id                 => $rating->id(),
                            rating             => $rating->rating(),
                            requires_qualifier => $rating->requires_qualifier()
                        }
        );
    }

    return \@results;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
