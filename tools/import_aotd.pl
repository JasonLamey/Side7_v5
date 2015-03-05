#!/usr/bin/env perl

use strict;
use warnings;

use Side7::Globals;
use Side7::User::AOTD;
use Side7::User::AOTD::Manager;

use 5.10.0;
use FindBin;
use lib "$FindBin::Bin/../lib";
use version; our $VERSION = qv( '1.0.0' );

use Data::Dumper;
use Getopt::Long;
use Carp;
use File::Find;
use IO::File;

Getopt::Long::Configure ("bundling");
use vars qw( $options $filecount );

$|++;

=pod


=head1 NAME

import_aotd.pl


=head1 DESCRIPTION

This script imports Artist of the Day records from the plain text files into DB records.
AOTD files are named 'aotd_yyyy-mm-dd.txt', and contain the User ID of that day's featured artist.
The date of the record is derived from the filename, and the User ID is from the file contents.


=head1 INVOCATION

    ./import_aotd.pl [-h|--help] [-v|--version] [-d|--date yyyy-mm-dd] [--verbose]

=cut


# MAIN
$options = get_options();

say "\nAOTD Record Importer";

if ( exists $options->{'date'} )
{
    print 'Date option not yet implemented. Do you wish to continue? [Y/n]: ';
    my $continue = <STDIN>;
    chomp $continue;
    $continue = 'y' if $continue eq ''; # default value.

    if ( lc( $continue ) ne 'y' )
    {
        say "User exited program.\n";
        exit 0;
    }

    say 'Processing all dates.'
}

say 'Beginning the importing of AOTD records.';

my $dbh = $DB->dbh || croak "Unable to establish DB handle: $DB->error";

$dbh->do( "TRUNCATE TABLE aotds" );
say 'AOTD table truncated.' if exists $options->{'verbose'};

my $import_dir = "$FindBin::Bin/../import/aotd";

say sprintf( 'Searching >%s< for files to import...', $import_dir ) if exists $options->{'verbose'};

$filecount = 0;
File::Find::find( \&parse_file, $import_dir );

say sprintf( 'Parsed %d files.', $filecount );


# METHODS AND FUNCTIONS

sub parse_file
{
    if ( -f $File::Find::name )
    {
        print sprintf( "\t> Parsing %s ...", $_ ) if exists $options->{'verbose'};

        my $date = $_;
        $date =~ s/^aotd_//;
        $date =~ s/\.txt$//;

        my $user_id = undef;
        my $fh = IO::File->new();
        if ( $fh->open( "< $File::Find::name" ) )
        {
            $user_id = <$fh>;
            chomp $user_id;
            $fh->close();
        }

        print " Date: $date || User_id: $user_id" if exists $options->{'verbose'};

        insert_record( date => $date, user_id => $user_id );

        $filecount++;
        say " DONE" if exists $options->{'verbose'};
    }
}

sub insert_record
{
    my ( %args ) = @_;

    my $date    = delete $args{'date'}    // undef;
    my $user_id = delete $args{'user_id'} // undef;

    if ( ! defined $date || ! defined $user_id )
    {
        croak( sprintf( 'Invalid date (>%s<) or user_id (>%s<) when attempting to insert record.', $date, $user_id ) );
    }

    my $aotd = Side7::User::AOTD->new( date => $date, user_id => $user_id );
    $aotd->save || croak( sprintf( 'DB save failed for date (>%s<) and user_id (>%s<): %s', $date, $user_id, $! ) );
}

sub get_options
{
    my %options = ();
    Getopt::Long::GetOptions(
                                \%options,
                                'help',
                                'version',
                                'date=s',
                                'verbose',
    ) || HELP_MSG();

    HELP_MSG()    if exists $options{'help'};
    VERSION_MSG() if exists $options{'version'};

    return \%options;
}

sub HELP_MSG
{
    say '';
    say sprintf( 'Usage: %s [-h|--help] [-v|--version] [-d|--date yyyy-mm-dd] [--verbose]', $0 );
    say '';
    say 'Options:';
    say "\t-h|--help\t\tThis output.";
    say "\t-v|--version\t\tProgram version.";
    say "\t-d|--date\t\tThe date to start from, in 'yyyy-mm-dd' format. If left out, all dates will be processed.";
    say "\t--verbose\t\tOutput additional progress messaging.";
    say '';
    exit;
}

sub VERSION_MSG
{
    say '';
    say sprintf( 'Side 7 Artist of the Day Importer - Version %s', $VERSION );
    say 'Copyright Side 7 1993-2015';
    say '';
    exit;
}
