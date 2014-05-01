#!/usr/bin/env perl

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use 5.010;

use Side7::Globals;
use Side7::User::Permission;
use Side7::User::RolesPermissionsMap;

use IO::File;
use Text::CSV;
use Getopt::Long;

my $options = retrieve_options();

if ( ! defined $options->{'file'} )
{
    say '';
    say 'ERROR: You must supply a .csv from which I can import.';
    say '';
    usage_exit();
}

if ( ! -e $options->{'file'} )
{
    say '';
    say "ERROR: Unfortunately, I couldn't find >$options->{'file'}<. Please supply a correct path and filename.";
    say '';
    usage_exit();
}

import_csv_file( file => $options->{'file'}, verbose => $options->{'verbose'} );

sub import_csv_file
{
    my ( %args ) = @_;

    my $file    = delete $args{'file'}    // undef;
    my $verbose = delete $args{'verbose'} // undef;

    if ( ! defined $file )
    {
        say 'ERROR: Filename failed to pass in for importing. Exiting.';
        exit;
    }

    say ">> Importing >$file< ..." if defined $verbose;

    my $csv = Text::CSV->new(
        {
            blank_is_undef => 1,
        },
    ) or die "Cannot use CSV: " . Text::CSV->error_diag();

    $csv->column_names(
                        "Permission",
                        "Guest",
                        "User",
                        "Subscriber",
                        "Forum Mod",
                        "Moderator",
                        "Admin",
                        "Owner",
                        "Purchaseable",
                        "Description"
    );

    my %roles = (
                    Guest       => 1,
                    User        => 2,
                    Subscriber  => 3,
                    "Forum Mod" => 4,
                    Moderator   => 5,
                    Admin       => 6,
                    Owner       => 7,
    );

    say ">> Opening .csv file >$file<";

    my $fh = IO::File->new();
    if ( $fh->open("< $file") )
    {
        while ( my $row = $csv->getline_hr( $fh ) )
        {
            say "\t>> Checking on permission >$row->{'Permission'}<";
            next if $row->{'Permission'} eq 'Permission'; # Skip any header line.

            my $perm = Side7::User::Permission->new( name => $row->{'Permission'} );
            my $loaded = $perm->load( speculative => 1 );

            if ( $loaded == 0 )
            {
                say "\tCould not load permission >$row->{'Permission'}< from the database.";
                next;
            }

            foreach my $role ( keys %roles )
            {
                if ( defined $row->{$role} && lc( $row->{$role} ) eq 'x' )
                {
                    say "\t\t>> Associating >$row->{'Permission'}< with >$role<" if $verbose;
                    my $role_perm_map = Side7::User::RolesPermissionsMap->new(
                        user_role_id  => $roles{$role},
                        permission_id => $perm->id,
                        created_at    => 'now()',
                        updated_at    => 'now()',
                    );

                    $role_perm_map->save();
                }
            }
        }
        $csv->eof or $csv->error_diag();

        $fh->close();
    }
    else
    {
        die "Could not open the file >$file<: $!";
    }

}

sub retrieve_options
{
    my %options = ();
    Getopt::Long::GetOptions(
        \%options,
        'file=s',
        'verbose!',
        'help!',
    ) || usage_exit();

    if ( defined $options{'help'} )
    {
        usage_exit();
    }
   
    return \%options;
}

sub usage_exit
{
    my @commands = split( /\//x, $0 );
    my $script = $commands[-1];

    say "$script, Copyright (C) 2014 Side 7";
    say '';
    say 'Usage:';
    say "$script [ OPTIONS ]";
    say '';
    say 'Options:';
    say '';
    say "--file <filename>\tThe .csv file from which to import records.";
    say "--verbose\t\tDisplays status messages as the script runs.";
    say "--help | -h\t\tDisplays this message.";

    exit;
}
