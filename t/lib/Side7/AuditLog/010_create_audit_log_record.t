use strict;
use warnings;

unshift @INC, '/usr/home/badkarma/src/dancer_projects/side7v5/Side7/lib';

use Test::More tests => 4;

use DateTime;

use_ok('Side7');
use_ok('Side7::AuditLog');

#        my $audit_log = Side7::AuditLog->new(
#                                                title       => 'Successful Login',
#                                                description => $success_message,
#                                                ip_address  => request->address() . $remote_host,
#                                                timestamp   => DateTime->now(),
#        );
#        $audit_log->save();

# Insert a record, and ensure an audit log ID is returned.
my $audit_log = Side7::AuditLog->new(
                                        title       => 'Test Log Entry',
                                        description => 'This is a test entry, and means nothing.',
                                        ip_address  => '192.168.2.100',
                                        timestamp   => DateTime->now(),
                                    );
$audit_log->save();
my $log_id = $audit_log->id();

is( defined $log_id, 1, 'Audit Log has a defined ID.' );
is( $log_id =~ m/\d+/, 1, 'Audit Log has a numerical ID.');
