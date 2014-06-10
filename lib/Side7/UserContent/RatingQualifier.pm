package Side7::UserContent::RatingQualifier;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;
use Side7::UserContent::RatingQualifier::Manager;

=pod


=head1 NAME

Side7::UserContent::RatingQualifier


=head1 DESCRIPTION

This package represents the possible rating qualifiers User Content can have.


=head1 SCHEMA INFORMATION

    Table name: rating_qualifiers

    | id           | int(8) unsigned                            | NO   | PRI | NULL    | auto_increment |
    | name         | varchar(255)                               | NO   |     | NULL    |                |
    | symbol       | char(1)                                    | NO   |     | NULL    |                |
    | description  | text                                       | YES  |     | NULL    |                |
    | content_type | enum('Image','Literature','Music','Video') | NO   | MUL | NULL    |                |
    | priority     | int(5)                                     | NO   |     | NULL    |                |
    | created_at   | datetime                                   | NO   |     | NULL    |                |
    | updated_at   | datetime                                   | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Class::Name

TODO: Define the relationship type, and list the foreign key (FK).

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'rating_qualifiers',
    columns => [ 
        id           => { type => 'serial', not_null => 1 },
        name         => { type => 'varchar', length => 255, not_null => 1 }, 
        symbol       => { type => 'char',    length => 1,   not_null => 1 }, 
        description  => { type => 'text', }, 
        content_type => { 
                          type    => 'enum',
                          values  => [ qw/Image Literature Music Video/ ],
                          default => 'Image',
        }, 
        priority     => { type => 'integer', length => 5,   not_null => 1 }, 
        created_at   => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at   => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'content_type' ],
);


=head1 METHODS


=head2 get_rating_qualifiers_for_form()

Returns an array ref of keys and values for rating qualifiers, depending upon the content type provided.

Parameters:

=over 4

=item content_type: The Content type to filter on. Accepts 'image', 'music', or 'literature'.

=back

    my $ratings = Side7::UserContent::RatingQualifier->get_rating_qualifiers_for_form( content_type => $content_type );

=cut

sub get_rating_qualifiers_for_form
{
    my ( $self, %args ) = @_;

    my $content_type = delete $args{'content_type'} // undef;

    return [] if ! defined $content_type;

    my $qualifiers = Side7::UserContent::RatingQualifier::Manager->get_rating_qualifiers(
        query =>
        [
            content_type => $content_type,
        ],
        sort_by => 'priority ASC',
    );

    my @results = ();
    foreach my $qualifier ( @{ $qualifiers } )
    {
        push( @results, { 
                            id     => $qualifier->id(), 
                            name   => $qualifier->name(), 
                            symbol => $qualifier->symbol(), 
                        }
        );
    }

    return \@results;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
