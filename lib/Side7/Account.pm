package Side7::Account;

use strict;
use warnings;

#use Side7::User;
use base 'Side7::DB::Object';

use Side7::Globals;

=pod

=head1 NAME

Side7::Account

=head1 DESCRIPTION

This class represents the account records for a user. The account holds all non-login
information, and is the model to which all other models are related.

=head1 SCHEMA INFORMATION

	Table name: accounts
	
	id                      :integer          not null, primary key
	user_id                 :integer          not null
	first_name              :string(45)
	last_name               :string(45)
	user_type_id            :integer          default(1), not null
	user_status_id          :integer          default(1), not null
	user_role_id            :integer          default(1), not null
	reinstate_on            :date
	other_aliases           :string(255)
	biography               :text
    sex                     :enum             not null
	birthday                :date             not null
	birthday_visibility     :integer          default(1), not null
	webpage_name            :string(255)
	webpage_url             :string(255)
	blog_name               :string(255)
	blog_url                :string(255)
	aim                     :string(45)
	yahoo                   :string(45)
	gtalk                   :string(45)
	skype                   :string(45)
	state                   :string(255)
	country_id              :integer
	is_public               :integer
	referred_by             :integer
	subscription_expires_on :date
	delete_on               :date
	delete_on               :string(100)      default(NULL)
	created_at              :datetime         not null
	updated_at              :datetime         not null

=cut

=pod

=head1 RELATIONSHIPS

=over

=item Side7::User

One-to-one relationship. FK = user_id

=item Side7::User::Type

One-to-one relationship. FK = user_type_id

=item Side7::User::Status

One-to-one relationship. FK = user_status_id

=item Side7::User::Role

One-to-one relationship. FK = user_role_id

=item Side7::DateVisibility

One-to-one relationship. FK = birthday_visibility

=item Side7::User::Country

One-to-one relationship. FK = country_id

=back

=cut

__PACKAGE__->meta->setup
(
    table   => 'accounts',
    columns => 
    [
        id                      => { type => 'serial', not_null => 1 },
        user_id                 => { type => 'integer', not_null => 1 },
        first_name              => { type => 'varchar', length => 45 },
        last_name               => { type => 'varchar', length => 45 },
        user_type_id            => { type => 'integer', not_null => 1 },
        user_status_id          => { type => 'integer', not_null => 1 },
        user_role_id            => { type => 'integer', not_null => 1 },
        reinstate_on            => { type => 'date' },
        other_aliases           => { type => 'varchar', length => 255 },
        biography               => { type => 'text' },
        sex                     => { 
                                    type    => 'enum', 
                                    values  => [qw/Male Female Trans* Neither Other Unspecified/], 
                                    default => 'Unspecified' 
        },
        birthday                => { type => 'date', not_null => 1 },
        birthday_visibility     => { type => 'integer', length => 1, not_null => 1, default => 1 },
        webpage_name            => { type => 'varchar', length => 255 },
        webpage_url             => { type => 'varchar', length => 255 },
        blog_name               => { type => 'varchar', length => 255 },
        blog_url                => { type => 'varchar', length => 255 },
        aim                     => { type => 'varchar', length => 45 },
        yahoo                   => { type => 'varchar', length => 45 },
        gtalk                   => { type => 'varchar', length => 45 },
        skype                   => { type => 'varchar', length => 45 },
        state                   => { type => 'varchar', length => 255 },
        country_id              => { type => 'integer' },
        is_public               => { type => 'integer' },
        referred_by             => { type => 'integer' },
        subscription_expires_on => { type => 'date' },
        delete_on               => { type => 'date' },
        confirmation_code       => { type => 'varchar', length => 100 },
        created_at              => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at              => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'user_id' ], [ 'confirmation_code' ], ],
    allow_inline_column_values => 1,
    foreign_keys =>
    [
        user =>
        {
            class             => 'Side7::User',
            key_columns       => { user_id => 'id' },
            relationship_type => 'one to one',
        },
        user_type =>
        {
            class             => 'Side7::User::Type',
            key_columns       => { user_type_id => 'id' },
            relationship_type => 'many to one',
        },
        user_status =>
        {
            class             => 'Side7::User::Status',
            key_columns       => { user_status_id => 'id' },
            relationship_type => 'many to one',
        },
        user_role =>
        {
            class             => 'Side7::User::Role',
            key_columns       => { user_role_id => 'id' },
            relationship_type => 'many to one',
        },
        country =>
        {
            class             => 'Side7::User::Country',
            key_columns       => { country_id => 'id' },
            relationship_type => 'many to one',
        },
        referred_by =>
        {
            class             => 'Side7::Account',
            key_columns       => { referred_by => 'id' },
            relationship_type => 'many to one',
        },
        bday_visiblity =>
        {
            class             => 'Side7::DateVisibility',
            key_columns       => { birthday_visibility => 'id' },
            relationship_type => 'many to one',
        },
    ],
);


=pod


=head1 METHODS


=head2 RDBO

    Inherits all RDBO methods.

=head2 full_name()

    $account->full_name();

=over

=item Returns a string containing the C<first_name> and C<last_name> fields concatonated.

=back

=cut

sub full_name
{
    my $self = shift;

    return undef if ! defined $self;

    my $separator = (
                        defined $self->{'first_name'} 
                        && 
                        $self->{'first_name'} ne '' 
                        && 
                        defined $self->{'last_name'} 
                        && 
                        $self->{'last_name'} ne ''
    ) ? ' ' : '';

    return ($self->{'first_name'} || '') .
            $separator .
           ($self->{'last_name'}  || '');
}


=head2 get_formatted_birthday()

    $account->get_formatted_birthday();

=over

=item Returns a string containing the C<birthday> field formatted appropriately for display.

=back

=cut

sub get_formatted_birthday
{
    my ( $self, %args ) = @_;

    return undef if ! defined $self;

    my $date_format = delete $args{'date_format'} // '%d %B, %Y'; # '01 January, 2014'

    if ( 
        $self->birthday_visibility == 3 
        ||
        ! defined $self->birthday
        ||
        $self->birthday eq '0000-00-00'
    )
    {
        return '[ Private ]';
    }
    elsif ( $self->birthday_visibility == 2 )
    {
        $date_format = '%d %B';
    }
    else
    {
        $date_format = '%d %B, %Y';
    }

    my $date = $self->birthday( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_formatted_subscription_expires_on()

    $account->get_formatted_subscription_expires_on();

=over

=item Returns a string containing the C<subscription_expires_on> field formatted appropriately for display.

=back

=cut

sub get_formatted_subscription_expires_on
{
    my ( $self, %args ) = @_;

    return undef if ! defined $self;

    my $date_format = delete $args{'date_format'} // '%d %B, %Y'; # '01 January, 2014'

    if ( $self->user_type->user_type ne 'Subscriber' )
    {
        return 'Not a Subscriber';
    }

    my $date = $self->subscription_expires_on( format => $date_format ) // 'Invalid Date';

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_formatted_delete_on()

    $account->get_formatted_delete_on();

=over

=item Returns a string containing the C<delete_on> field formatted appropriately for display.

=back

=cut

sub get_formatted_delete_on
{
    my ( $self, %args ) = @_;

    return undef if ! defined $self;

    my $date_format = delete $args{'date_format'} // '%A, %d %B, %Y'; # 'Monday, 01 January, 2014'

    my $date = $self->delete_on( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_formatted_created_at()

    $account->get_formatted_created_at();

=over

=item Returns a string containing the C<created_at> field formatted appropriately for display.

=back

=cut

sub get_formatted_created_at
{
    my ( $self, %args ) = @_;

    return undef if ! defined $self;

    my $date_format = delete $args{'date_format'} // '%A, %d %B, %Y'; # 'Monday, 01 January, 2014'

    my $date = $self->created_at( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_formatted_updated_at()

    $account->get_formatted_updated_at();

=over

=item Returns a string containing the C<updated_at> field formatted appropriately for display.

=back

=cut

sub get_formatted_updated_at
{
    my ( $self, %args ) = @_;

    return undef if ! defined $self;

    my $date_format = delete $args{'date_format'} // '%A, %d %B, %Y'; # 'Monday, 01 January, 2014'

    my $date = $self->updated_at( format => $date_format ) // undef;

    if ( defined $date )
    {
        $date =~ s/ 1$//; # Unsure why, but the returned formatted date always appends a > 1< to the end.
    }

    return $date;
}


=head2 get_account_hash_for_template()

Returns a hash reference for the appropriate account data values, formatted properly.

    my $account_hash = $account->get_account_hash_for_template();

=cut

sub get_account_hash_for_template
{
    my ( $self, %args ) = @_;

    return {} if ! defined $self;

    my $filter_profanity = delete $args{'filter_profanity'} // 1;

    my $account_hash = {};

    # General data
    $account_hash->{'full_name'} = $self->full_name();

    foreach my $key (
        qw(
            id first_name last_name biography sex webpage_name webpage_url
            blog_name blog_url aim yahoo gtalk skype state
        )
    )
    {
        $account_hash->{$key} = $self->$key;
    }

    # Account Stats
    $account_hash->{'status'} = $self->user_status->user_status();
    $account_hash->{'type'}   = $self->user_type->user_type();
    $account_hash->{'role'}   = $self->user_role->name();

    # Date values
    $account_hash->{'birthday'}                = $self->get_formatted_birthday();
    $account_hash->{'subscription_expires_on'} = $self->get_formatted_subscription_expires_on();
    $account_hash->{'delete_on'}               = $self->get_formatted_delete_on();
    $account_hash->{'created_at'}              = $self->get_formatted_created_at();
    $account_hash->{'updated_at'}              = $self->get_formatted_updated_at();

    # Filter Profanity
    if ( $filter_profanity == 1 )
    {
        foreach my $key ( qw/ full_name first_name last_name biography webpage_name blog_name / )
            {
                $account_hash->{$key} =
                    Side7::Utils::Text::filter_profanity( text => $account_hash->{$key} );
            }
    }

    return $account_hash;
}


=head1 FUNCTIONS


=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2014

=cut

1;
