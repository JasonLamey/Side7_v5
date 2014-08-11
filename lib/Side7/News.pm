package Side7::News;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;
use Side7::News::Manager;

=pod


=head1 NAME

Side7::News


=head1 DESCRIPTION

This package handles the setting and retrieval of site news headlines and articles.


=head1 SCHEMA INFORMATION

    Table name: news

    | id               | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | title            | varchar(255)        | NO   |     | NULL    |                |
    | blurb            | tinytext            | YES  |     | NULL    |                |
    | body             | text                | YES  |     | NULL    |                |
    | link_to_article  | varchar(255)        | YES  |     | NULL    |                |
    | is_static        | tinyint(1)          | NO   |     | 0       |                |
    | not_static_after | date                | YES  |     | NULL    |                |
    | priority         | tinyint(4)          | NO   |     | 1       |                |
    | user_id          | bigint(20) unsigned | NO   |     | NULL    |                |
    | created_at       | datetime            | NO   |     | NULL    |                |
    | updated_at       | datetime            | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

One-to-one relationship with User, using user_id as a FK.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'news',
    columns => [ 
        id               => { type => 'serial', not_null => 1 },
        title            => { type => 'varchar', length => 255,  not_null => 1 }, 
        blurb            => { type => 'text' }, 
        body             => { type => 'text' }, 
        link_to_article  => { type => 'varchar', length => 255 }, 
        is_static        => { type => 'boolean', not_null => 1, default => 0 }, 
        not_static_after => { type => 'date' }, 
        priority         => { type => 'integer', not_null => 1, default => 1 }, 
        user_id          => { type => 'integer', not_null => 1 }, 
        created_at       => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at       => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    foreign_keys =>
    [
        user =>
        {
            type       => 'one to one',
            class      => 'Side7::User',
            column_map => { user_id => 'id' },
        },
    ],
);

=head1 METHODS


=head2 get_news_article_list()

Returns an arrayref of news article hashes, based on the page to be viewed.

Parameters:

=over 4

=item page: The page number for which to return results.

=back

    my $news = Side7::News->get_news_article_list( page => $page );

=cut

sub get_news_article_list
{
    my ( $self, %args ) = @_;

    my $page = delete $args{'page'} // 1;

    my $results = Side7::News::Manager->get_news(
                                                    query => [
                                                                is_static => 0,
                                                             ],
                                                    with_objects => [ 'user' ],
                                                    sort_by  => 'created_at DESC',
                                                    page     => $page,
                                                    per_page => $CONFIG->{'page'}->{'default'}->{'pagination_limit'},
                                                );

    my $news = [];
    foreach my $result ( @$results )
    {
        push( @$news, $result->get_news_hash_for_template() );
    }

    my $stickies = Side7::News::Manager->get_news(
                                                    query => [
                                                                is_static => 1,
                                                                not_static_after => { ge => DateTime->today() },
                                                             ],
                                                    with_objects => [ 'user' ],
                                                    sort_by  => 'created_at DESC',
                                                    limit    => 5,
                                                 );

    my $sticky_news = [];
    foreach my $sticky ( @$stickies )
    {
        push( @$sticky_news, $sticky->get_news_hash_for_template() );
    }

    my $news_count = Side7::News::Manager->get_news_count(
                                                            query => [
                                                                        is_static => 0,
                                                                     ],
                                                         );

    my $data = {};

    $data->{'news_count'}  = $news_count;
    $data->{'news'}        = $news;
    $data->{'sticky_news'} = $sticky_news;
   
    return $data; 
}


=head1 get_news_hash_for_template()

Takes a News object and returns a hash structure of formatted values for use in a template.

Parameters:

=over 4

=item None

=back

    my $news_hash = $news->get_news_hash_for_template();

=cut

sub get_news_hash_for_template
{
    my ( $self ) = @_;

    my $news_hash = {};
    foreach my $field ( qw/ id title blurb body link_to_article priority / )
    {
        $news_hash->{$field} = $self->$field();
    }

    foreach my $field ( qw/ created_at updated_at / )
    {
        $news_hash->{$field} = $self->$field->strftime( '%d %b, %Y @ %I:%M %P' );
    }

    if ( defined $self->{'user'} )
    {
        $news_hash->{'user'} = $self->user->get_user_hash_for_template();
    }

    return $news_hash;
}


=head2 get_news_article()

Returns a hashref of news article data based on news id.

Parameters:

=over 4

=item news_id: The ID of the News item to return.

=back

    my $news_item = Side7::News->get_news_article( news_id => $news_id );

=cut

sub get_news_article
{
    my ( $self, %args ) = @_;

    my $news_id = delete $args{'news_id'} // undef;

    if ( ! defined $news_id )
    {
        return {};
    }

    my $news_item = Side7::News->new( id => $news_id );
    my $loaded = $news_item->load( speculative => 1, with => [ 'user' ] );

    my $news_hash = {};
    if ( $loaded != 0 && ref( $news_item ) eq 'Side7::News' )
    {
        $news_hash = $news_item->get_news_hash_for_template();
    }

    return $news_hash;
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
