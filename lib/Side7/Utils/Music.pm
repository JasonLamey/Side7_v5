package Side7::Utils::Music;

use strict;
use warnings;

use Const::Fast;
use Data::Dumper;
use Audio::File;
use Audio::Scan;

use Side7::Globals;
use Side7::Utils::File;

use version; our $VERSION = qv( '0.1.0' );

# Audio files map extention to file type:
const my %AUDIO_FILE_MAP => (
                                'mp3'  => 'mp3',
                                'mp2'  => 'mp3',
                                'mp4'  => 'mp4',
                                'm4a'  => 'mp4',
                                'm4b'  => 'mp4',
                                'm4p'  => 'mp4',
                                'm4v'  => 'mp4',
                                'm4r'  => 'mp4',
                                'k3g'  => 'mp4',
                                'skm'  => 'mp4',
                                '3gp'  => 'mp4',
                                '3g2'  => 'mp4',
                                'mov'  => 'mp4',
                                'aac'  => 'aac',
                                'ogg'  => 'ogg',
                                'oga'  => 'ogg',
                                'flc'  => 'flac',
                                'flac' => 'flac',
                                'fla'  => 'flac',
                                'mpc'  => 'musepack',
                                'mpp'  => 'musepack',
                                'mp+'  => 'musepack',
                                'wav'  => 'wav',
                                'aiff' => 'aiff',
                                'aif'  => 'aif',
                                'wv'   => 'wavpack',
                            );

# Tag/Info names from audio file headers
const my %AUDIO_TAG_NAMES => (
                                mp3 => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                mp4 => {
                                        bitrate    => 'avg_bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                aac => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                ogg => {
                                        bitrate    => 'bitrate_average',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                flac => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                asf => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                musepack => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                wav => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                aiff => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                                wavpack => {
                                        bitrate    => 'bitrate',
                                        samplerate => 'samplerate',
                                        length     => 'song_length_ms',
                                       },
                             );


=head1 NAME

Side7::Utils::Music


=head1 DESCRIPTION

This package provides utility functions for audio files.


=head1 METHODS


=head2 get_audio_stats( %parameters )

Receives a C<hash> containing all parameters. Returns a C<hashref> with filesize, format, encoding, length and bitrate,
by default. Individual returned values can be selected, if desired, via parameters.

Parameters:

=over 4

=item filepath: Full file path to the audio file. Required.

=item encoding: Boolean. Returns the encoding of the file as a C<string>. Defaults to false.

=item bitrate: Boolean. Returns the bitrate of the file as a C<string>. Defaults to false.

=item samplerate: Boolean. Returns the bitrate of the file as a C<string>. Defaults to false.

=item filesize: Boolean. Returns the filesize in bytes as a C<string>. Defaults to false.

=item length: Boolean. Returns the length in seconds as a C<string>. Defaults to false.

=back

    my $audio_stats = Side7::Utils::Music->get_audio_stats( filepath => $filepath );

=cut

sub get_audio_stats
{
    my ( $self, %args ) = @_;

    my $filepath       = delete $args{'filepath'}   // undef;
    my $get_encoding   = delete $args{'encoding'}   // undef;
    my $get_bitrate    = delete $args{'bitrate'}    // undef;
    my $get_samplerate = delete $args{'samplerate'} // undef;
    my $get_filesize   = delete $args{'filesize'}   // undef;
    my $get_length     = delete $args{'length'}     // undef;

    if
    (
        ! defined $filepath
        ||
        ! -f $filepath
    )
    {
        return { error => 'Undefined filepath or non-existent audio file passed in. >' . ( $filepath // '' ) . '<' };
    }

    my $extension  = Side7::Utils::File::get_file_extension( $filepath );
    if
    (
        ! defined $extension
        ||
        ! exists $AUDIO_FILE_MAP{ lc( $extension ) }
    )
    {
        return { error => 'Cannot determine file extension or unmapped file extension for: >' . $filepath . '<' };
    }

    my $scan_file  = Audio::Scan->scan( $filepath );

    my $encoding   = $AUDIO_FILE_MAP{ lc( $extension ) };
    my $bitrate    = $scan_file->{'info'}->{ $AUDIO_TAG_NAMES{ $encoding }{'bitrate'} };
    my $samplerate = $scan_file->{'info'}->{ $AUDIO_TAG_NAMES{ $encoding }{'samplerate'} };
    my $length     = int $scan_file->{'info'}->{ $AUDIO_TAG_NAMES{ $encoding }{'length'} };
    my $filesize   = ( stat( $filepath ) )[7];

    if (
        ! defined $get_encoding
        &&
        ! defined $get_bitrate
        &&
        ! defined $get_samplerate
        &&
        ! defined $get_filesize
        &&
        ! defined $get_length
    )
    {
        return   {
                    encoding   => $encoding,
                    bitrate    => $bitrate,
                    samplerate => $samplerate,
                    filesize   => $filesize,
                    length     => $length
                 };
    }

    my $stats = {};

    $stats->{encoding}   = $encoding   if defined $get_encoding;
    $stats->{bitrate}    = $bitrate    if defined $get_bitrate;
    $stats->{samplerate} = $samplerate if defined $get_samplerate;
    $stats->{filesize}   = $filesize   if defined $get_filesize;
    $stats->{length}     = $length     if defined $get_length;

    return $stats;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
