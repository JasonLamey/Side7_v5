use strict;
use warnings;

use Test::More tests => 14;
use Data::Dumper;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use_ok 'Side7';
use_ok 'Side7::Utils::Text';

# Attempt to get HTML elements from BBCode encodings.
# $parsed_text = Side7::Utils::Text::parse_bbcode_markup( $original_text, \%args );
# Default HTML tags: b, i, u, img, url, email, size, color, list, *, quote, code

is( Side7::Utils::Text::parse_bbcode_markup( '[b]test[/b]' ), '<b>test</b>', 'Bolded text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[i]test[/i]' ), '<i>test</i>', 'Italisized text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[u]test[/u]' ), '<u>test</u>', 'Underlined text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[url]http://www.test.com[/url]' ), '<a href="http://www.test.com" rel="nofollow">http://www.test.com</a>', 'Basic URL text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[url=http://www.test.com]test[/url]' ), '<a href="http://www.test.com" rel="nofollow">test</a>', 'Custom URL text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[img]http://www.test.com[/img]' ), '<img src="http://www.test.com" alt="[http://www.test.com]" title="http://www.test.com">', 'Image text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[email]test@test.com[/email]' ), '<a href="mailto:test@test.com">test@test.com</a>', 'Email text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[quote="author"]test[/quote]' ), qq|<div class="bbcode_quote_header">author:\n<div class="bbcode_quote_body">test</div></div>\n|, 'Block quote text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[code]test[/code]' ), qq|<div class="bbcode_code_header">Code:\n<div class="bbcode_code_body">test</div></div>\n|, 'Code/monospace text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[size=15px]test[/size]' ), '<span style="font-size: 0">test</span>', 'Sized text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[color=#FF0000]test[/color]' ), '<span style="color: #FF0000">test</span>', 'Colored text.' );
is( Side7::Utils::Text::parse_bbcode_markup( '[list] [*]Entry 1 [*]Entry 2 [/list]' ), '<ul> <li>Entry 1 </li><li>Entry 2 </li></ul>', 'Listed text.' );
