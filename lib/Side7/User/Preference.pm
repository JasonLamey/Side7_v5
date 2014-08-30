package Side7::User::Preference;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::User::Preference

=head1 DESCRIPTION

This package handles all the management for User Preferences.

=head1 SCHEMA INFORMATION

    Table name: user_preferences

    | id                         | bigint(20) unsigned                                             | NO   | PRI | NULL        | auto_increment |
    | user_id                    | int(8) unsigned                                                 | NO   | MUL | NULL        |                |
    | display_signature          | tinyint(1)                                                      | NO   |     | 0           |                |
    | show_management_thumbs     | tinyint(1)                                                      | NO   |     | 1           |                |
    | default_comment_visibility | enum('Show','Hide')                                             | NO   |     | Show        |                |
    | default_comment_type       | enum('Any','Commentary Only','Light Critique','Heavy Critique') | NO   |     | Any         |                |
    | allow_watching             | tinyint(1)                                                      | NO   |     | 1           |                |
    | allow_favoriting           | tinyint(1)                                                      | NO   |     | 1           |                |
    | allow_sharing              | tinyint(1)                                                      | NO   |     | 1           |                |
    | allow_email_through_forms  | tinyint(1)                                                      | NO   |     | 1           |                |
    | allow_pms                  | tinyint(1)                                                      | NO   |     | 1           |                |
    | pms_notifications          | tinyint(1)                                                      | NO   |     | 1           |                |
    | comment_notifications      | tinyint(1)                                                      | NO   |     | 1           |                |
    | show_online                | tinyint(1)                                                      | NO   |     | 1           |                |
    | thumbnail_size             | enum('Small','Medium','Large')                                  | NO   |     | Small       |                |
    | content_display_type       | enum('List','Grid')                                             | NO   |     | List        |                |
    | show_m_thumbs              | tinyint(1)                                                      | NO   |     | 0           |                |
    | show_adult_content         | tinyint(1)                                                      | NO   |     | 0           |                |
    | display_full_sized_images  | enum('Same Window','New Window')                                | NO   |     | Same Window |                |
    | filter_profanity           | tinyint(1)                                                      | NO   |     | 1           |                |
    | created_at                 | datetime                                                        | NO   |     | NULL        |                |
    | updated_at                 | datetime                                                        | NO   |     | NULL        |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

Many to one relationship, with user_id being the FK

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_preferences',
    columns => [ 
        id                         => { type => 'serial',   not_null => 1 },
        user_id                    => { type => 'integer',  not_null => 1 },
        display_signature          => { type => 'boolean',  not_null => 1, default => 0 },
        show_management_thumbs     => { type => 'boolean',  not_null => 1, default => 1 },
        default_comment_visibility => { 
                                        type     => 'enum',  
                                        values   => [ 'Show', 'Hide' ],  
                                        not_null => 1,
                                        default  => 'Show',
                                      }, 
        default_comment_type       => { 
                                        type     => 'enum',
                                        values   => [ 'Any', 'Commentary Only', 'Light Critique', 'Heavy Critique' ],
                                        not_null => 1,
                                        default  => 'Any',
                                      }, 
        allow_watching             => { type => 'boolean',  not_null => 1, default => 1 },
        allow_favoriting           => { type => 'boolean',  not_null => 1, default => 1 },
        allow_sharing              => { type => 'boolean',  not_null => 1, default => 1 },
        allow_email_through_forms  => { type => 'boolean',  not_null => 1, default => 1 },
        allow_pms                  => { type => 'boolean',  not_null => 1, default => 1 },
        pms_notifications          => { type => 'boolean',  not_null => 1, default => 1 },
        comment_notifications      => { type => 'boolean',  not_null => 1, default => 1 },
        show_online                => { type => 'boolean',  not_null => 1, default => 1 },
        thumbnail_size             => { 
                                        type     => 'enum',  
                                        values   => [ 'Small', 'Medium', 'Large' ],  
                                        not_null => 1,
                                        default  => 'Small',
                                      }, 
        content_display_type       => { 
                                        type     => 'enum',  
                                        values   => [ 'List', 'Grid' ],  
                                        not_null => 1,
                                        default  => 'List',
                                      }, 
        show_m_thumbs              => { type => 'boolean',  not_null => 1, default => 0 },
        show_adult_content         => { type => 'boolean',  not_null => 1, default => 0 },
        display_full_sized_images  => { 
                                        type     => 'enum',  
                                        values   => [ 'Same Window', 'New Window' ],  
                                        not_null => 1,
                                        default  => 'Same Window',
                                      }, 
        filter_profanity           => { type => 'boolean',  not_null => 1, default => 1 },
        created_at                 => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at                 => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'user_id' ],
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
