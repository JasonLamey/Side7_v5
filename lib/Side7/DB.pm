package Side7::DB;

=pod

=head1 NAME

Side7::DB

=head1 DESCRIPTION

This class handles the database configuration and connection.
It inherits from Rose::DB.

=cut

use Rose::DB;
our @ISA = qw( Rose::DB );
use Rose::DB::Object::QueryBuilder qw( build_select );

use Data::Dumper;
use Carp qw( confess );
use List::Util;

use Side7::Globals;

# Use a private registry for this class
Side7::DB->use_private_registry;

# Register your data sources using the default type and domain
Side7::DB->register_db(
  domain   => 'development',
  type     => 'main',
  driver   => 'MySQL',
  database => 'side7_v5_dev',
  host     => 'localhost',
  username => 's7dev',
  password => 'ArtR0x',
);

Side7::DB->register_db(
  domain   => 'production',
  type     => 'main',
  driver   => 'MySQL',
  database => 'side7_v5_prod',
  host     => 'localhost',
  username => 's7prod',
  password => '0niPurRz!',
);

# TODO: THIS LAST REGISTRATION IS FOR MIGRATION PURPOSES - It needs to be removed before site launch.

Side7::DB->register_db(
  domain   => 'current',
  type     => 'main',
  driver   => 'MySQL',
  database => 'side7_v4',
  host     => 'localhost',
  username => 's7old',
  password => 's7CPR',
);

# Set the domain
Side7::DB->default_domain( 'development' );
Side7::DB->default_type( 'main' );

#our $DB = Side7::DB->new();

=head1 FUNCTIONS

=head2 get_db()

    my $DB = Side7::DB::get_db( domain => $domain, type => $type );

Returns a DB object, with the domain and type settings.  Both domain and type are optional. Domain defaults to 'development', and type defaults to 'main'.

=cut

sub get_db
{
    my %args = @_;

    my $domain = delete $args{'domain'} || 'development';
    my $type   = delete $args{'type'}   || 'main';

    my $DB = Side7::DB->new( domain => $domain, type => $type );
    return $DB;
}

=head2 build_select()

    my $results_hashref = Side7::DB::build_select();

Returns a hashref of selected results from the DB, based on the parameters passed in.
Refer to the L<Rose::DB::Object::QueryBuilder CPAN page|http://search.cpan.org/dist/Rose-DB-Object/lib/Rose/DB/Object/QueryBuilder.pm> for more info.

    my $result = Side7::DB::build_select(
                                            select  => 'OLD_PASSWORD(?) as db_pass',
                                            tables  => [ 'users' ],
                                            columns => { users => [ 'db_pass' ] },
                                            query   => [],
                                            bind    => [ $string ],
                                            limit   => 1,
                                        );


=cut

sub build_select
{
    my ( %args ) = @_;

    my $select  = delete $args{'select'}  // undef; # Optional, specific fields or SQL functions, e.g., "COUNT(*)'
    my $tables  = delete $args{'tables'}  // [];    # Mandatory, Array of table names
    my $columns = delete $args{'columns'} // {};    # Mandatory, hash of array refs of columns, keyed to each table
    my $query   = delete $args{'query'}   // [];    # Mandatory, Where clauses, in a hash of scalars, array refs, and hash refs
    my $sort_by = delete $args{'sort_by'} // undef; # Optional, body of the sort by clause, e.g.,  "name ASC, date DESC"
    my $limit   = delete $args{'limit'}   // undef; # Optional, string of the limit body, e.g., 5
    my $bind    = delete $args{'bind'}    // [];    # Optional, bind parameters

    my $dataset_type = delete $args{'dataset_type'} // 'hashref'; # hashref or arrayref

    if ( ! defined $tables || ref $tables ne 'ARRAY' )
    {
        confess( 'Error creating query; missing table names or tables not an array.' );
        return undef;
    }

    if ( ! defined $columns || ref $columns ne 'HASH' )
    {
        confess( 'Error creating query; missing column names or columns not a hash.' );
        return undef;
    }

    if ( ! defined $query || ref $query ne 'ARRAY' )
    {
        confess( 'Error creating query; missing query values or query not an array.' );
        return undef;
    }

    $DB //= $Side7::Globals::DB;

    my $dbh = $DB->dbh;

    my $sql = Rose::DB::Object::QueryBuilder::build_select (
        db              => $DB,
        dbh             => $dbh,
        query_is_sql    => 1,
        select          => $select,
        tables          => $tables,
        columns         => $columns,
        query           => $query,
        sort_by         => $sort_by,
        limit           => $limit,
    );

    #warn('SQL: '.$sql);

    my $sth = $dbh->prepare($sql);
    $sth->execute(@$bind);

    my @rows;
    if ( $dataset_type eq 'arrayref' )
    {
        while ( my $row = $sth->fetchrow_arrayref )
        {
            push( @rows, $row );
        }
        return \@rows;
    }

    while ( my $row = $sth->fetchrow_hashref )
    {
        push( @rows, $row );
    }

    return \@rows;
}


=head2 get_enum_values_for_form()

Retrieves the enum values for one or more fields from a table. Takes an array of field names for which to check
for the values, and passes back a hash of arrays with the enum values for each field.

Parameters:

=over 4

=item fields: An array of field names to match against.

=item table: The table against which to check for enum values.

=back

    my $enum_values = Side7::DB::get_enum_values_for_form( fields => [ $field_name, $another_field ], table => $table );

=cut

sub get_enum_values_for_form
{
    my ( %args ) = @_;
    my $fields = delete $args{'fields'} // [];
    my $table  = delete $args{'table'}  // undef;

    return {} if ! defined $table;
    return {} if scalar( @{ $fields } ) == 0;

    $DB //= $Side7::Globals::DB;

    my $dbh = $DB->dbh;

    my $sth = $dbh->column_info( undef, undef, $table, '%' );

    my %enum_field_values = ();
    while ( my $col_info  = $sth->fetchrow_hashref )
    {
        if 
        (
            ( List::Util::any { $col_info->{'COLUMN_NAME'} eq $_ } @{ $fields } )
            &&
            $col_info->{'TYPE_NAME'} eq 'ENUM'
        )
        {
            # The mysql_values key contains a reference to an array of valid enum values
            $enum_field_values{ $col_info->{'COLUMN_NAME'} } = $col_info->{'mysql_values'};
        }
    }

    return \%enum_field_values;
}
 

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2014

=cut

1;
