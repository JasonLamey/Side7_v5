#!/usr/bin/env perl

use strict;
use warnings;

use v5.10;

use Pod::Simple::HTMLBatch;
use Getopt::Long;
use Const::Fast;

const my $DEFAULT_POD_ROOT   => '/home/badkarma/src/dancer_projects/side7v5/Side7/lib/';
const my $DEFAULT_POD_OUTPUT => '/home/badkarma/src/dancer_projects/side7v5/Side7/public/pod_manual/';

my $options = retrieve_options();

my $pod_convert = Pod::Simple::HTMLBatch->new();

$pod_convert->verbose( 1 );
$pod_convert->index( 1 );
$pod_convert->contents_file( 'index.html' );
$pod_convert->contents_page_start( 'Side 7 Documentation' );
$pod_convert->batch_convert(
        ( $options->{'podroot'}   // $DEFAULT_POD_ROOT ), 
        ( $options->{'podoutput'} // $DEFAULT_POD_OUTPUT ),
);

sub retrieve_options
{
    my %options;

    Getopt::Long::GetOptions(
        \%options,
        'verbose!',
        'podroot:s',
        'podoutput:s',
        'help!',
    ) || exit_usage();

    exit_usage() if $options{'help'};

    return \%options;
}

sub exit_usage
{
    say 'Help info here.';

    exit 0;
}
