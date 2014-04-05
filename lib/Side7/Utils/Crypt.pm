package Side7::Utils::Crypt;

use strict;
use warnings;

use Digest::SHA1 qw(sha1);
use Digest::MD5;

use Side7::Globals;
use Side7::DB;

=pod

=head1 NAME

Side7::Utils::Crypt

=head1 DESCRIPTION

This package has the appropriate functionality for hashing passwords, codes, and other items that need to be made more ambiguious.

=cut


=head1 FUNCTIONS


=head2 sha1_hex_encode

    $sha1_encoded_text = Side7::Utils::Crypt::sha1_hex_encode( $text );

Returns a SHA1 hex encoded version of the provided string.

=cut

sub sha1_hex_encode
{
    my ( $string ) = @_;

    return undef if ! defined $string;

    my $sha1 = Digest::SHA1->new;
    $sha1->add( $string );
    my $digest = $sha1->hexdigest // '';

    return $digest;
}


=head2 md5_hex_encode

    $md5_encoded_text = Side7::Utils::Crypt::md5_hex_encode( $text );

Returns an MD5 hex encoded version of the provided string.

=cut

sub md5_hex_encode
{
    my ( $string ) = @_;

    return undef if ! defined $string;

    my $md5 = Digest::MD5->new;
    $md5->add( $string );
    my $digest = $md5->hexdigest // '';

    return $digest;
}


=head2 old_side7_crypt

    $old_crypt = Side7::Utils::Crypt::old_side7_crypt( $text );

Returns an old-style Side 7 v2 crypt version of the provided string.

=cut

sub old_side7_crypt
{
    my ( $string ) = @_;

    return undef if ! defined $string;

    return crypt($string, 'S7');
}


=head2 old_mysql_password

    $old_pw = Side7::Utils::Crypt::old_mysql_password( $text );

Returns an old-style MySQL password version of the provided string.

=cut

sub old_mysql_password
{
    my ( $string ) = @_;

    return undef if ! defined $string;

    my $result = Side7::DB::build_select(
        select  => 'OLD_PASSWORD(?) as db_pass',
        tables  => [ 'users' ],
        columns => { users => [ 'db_pass' ] },
        query   => [],
        bind    => [ $string ],
        limit   => 1,
    );
    my $db_pass = $result->[0]->{'db_pass'} // '';

    return $db_pass;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
