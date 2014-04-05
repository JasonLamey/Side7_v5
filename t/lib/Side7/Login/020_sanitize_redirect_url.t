use strict;
use warnings;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Test::More tests => 7;

use_ok('Side7');
use_ok('Side7::Login');

# my $rd_url = Side7::Login::sanitize_redirect_url(
#         { rd_url => params->{'rd_url'}, referer => request->referer, uri_base => request->uri_base }
# );

my $EXTERNAL_URL = 'http://www.google.com/search';
my $INTERNAL_URL = 'http://localhost:3000/user/badkarma';
my $SECURE_URL   = 'https://localhost:3000/user/badkarma';

my $EXTERNAL_REFERER = 'http://www.google.com/search';
my $INTERNAL_REFERER = 'http://localhost:3000/user/furrball';

my $URI_BASE = 'http://localhost:3000';

# Sanitize external redirect URL, no referer
my $sanitized_external = Side7::Login::sanitize_redirect_url( 
        { rd_url => $EXTERNAL_URL, referer => undef, uri_base => $URI_BASE, }
);

is( $sanitized_external, '/search', 'External redirect URL, no referer, go to localized URI.' );

# Sanitized internal redirect URL, no referer
my $sanitized_internal = Side7::Login::sanitize_redirect_url( 
        { rd_url => $INTERNAL_URL, referer => undef, uri_base => $URI_BASE, }
);

is( $sanitized_internal, '/user/badkarma', 'Internal redirect URL, no referer, go to localized URI.' );

# Sanitized external referer, no rd_url.
my $sanitized_external_ref = Side7::Login::sanitize_redirect_url( 
        { rd_url => undef, referer => $EXTERNAL_REFERER, uri_base => $URI_BASE, }
);

is( $sanitized_external_ref, '/', 'External referer URL, no rd_url, go to index.' );

# Sanitized internal referer URL, no rd_url
my $sanitized_internal_ref = Side7::Login::sanitize_redirect_url( 
        { rd_url => undef, referer => $INTERNAL_REFERER, uri_base => $URI_BASE, }
);

is( $sanitized_internal_ref, '/user/furrball', 'Internal referer URL, no rd_url, go to localized URI.' );

# Sanitized redirect, no rd_url, no referer
my $sanitized_blind = Side7::Login::sanitize_redirect_url( 
        { rd_url => undef, referer => undef, uri_base => $URI_BASE, }
);

is( $sanitized_blind, '/', 'No referer, no rd_url, go to index.' );

