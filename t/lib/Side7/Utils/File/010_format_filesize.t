use strict;
use warnings;

use Test::More tests => 8;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::File';

# Attempt to get a formatted filesize.

my %filesizes = (
    '10_bytes' => { bytes =>               10, output => '10 B'   },
    '512_kb'   => { bytes =>           524288, output => '512 KB' },
    '16_mb'    => { bytes =>         16777216, output => '16 MB'  },
    '2_gb'     => { bytes =>       2147483648, output => '2 GB'   },
    '4_tb'     => { bytes =>    4398046511104, output => '4 TB'   },
    '1_pb'     => { bytes => 1125899906842624, output => '1 PB'   },
);

foreach my $filesize ( keys %filesizes )
{
    my $size = Side7::Utils::File::get_formatted_filesize_from_bytes( $filesizes{$filesize}{'bytes'} );
    is( $size, $filesizes{$filesize}{'output'}, "$filesize returned correctly formatted." );
}
