use strict;
use warnings;

use Test::More tests => 7;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::Text';

# Ensure that text handed to this function returns a modified string.

my $STRING_W_DQ = q|The cat said "Meow."|;
my $STRING_W_SQ = q|The moon was 'green.'|;
my $STRING_W_LT = q|Fred typed <3.|;
my $STRING_W_GT = q|Bob knows 5 > 2.|;
my $STRING_W_ALL = q|Jim's snake hissed, "Ssssss." <Really.>|;

my $MOD_STRING_W_DQ = q|The cat said &quot;Meow.&quot;|;
my $MOD_STRING_W_SQ = q|The moon was &apos;green.&apos;|;
my $MOD_STRING_W_LT = q|Fred typed &lt;3.|;
my $MOD_STRING_W_GT = q|Bob knows 5 &gt; 2.|;
my $MOD_STRING_W_ALL = q|Jim&apos;s snake hissed, &quot;Ssssss.&quot; &lt;Really.&gt;|;

is( Side7::Utils::Text::sanitize_text_for_html( $STRING_W_DQ ),  $MOD_STRING_W_DQ,  'Double-quote sanitized');
is( Side7::Utils::Text::sanitize_text_for_html( $STRING_W_SQ ),  $MOD_STRING_W_SQ,  'Single-quote sanitized');
is( Side7::Utils::Text::sanitize_text_for_html( $STRING_W_LT ),  $MOD_STRING_W_LT,  'Less than sanitized');
is( Side7::Utils::Text::sanitize_text_for_html( $STRING_W_GT ),  $MOD_STRING_W_GT,  'Greater than sanitized');
is( Side7::Utils::Text::sanitize_text_for_html( $STRING_W_ALL ), $MOD_STRING_W_ALL, 'Mixed characters sanitized');

