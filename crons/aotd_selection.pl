#!/usr/bin/env perl

use strict;
use 5.10.0;

use FindBin;
use lib "$FindBin::Bin/../lib";
use version; our $VERSION = qv( '2.0' );

use Side7::Globals;
use Side7::User;
use Side7::User::AOTD;
use Side7::Account::Manager;
use Side7::PrivateMessage;
use Side7::AuditLog;

use Carp;
use Const::Fast;
use DateTime;
use Template;
use Email::Sender::Simple;
use Email::Sender::Transport::Sendmail;
use Email::Simple;
use Email::Simple::Creator;

const our $MIN_WEIGHT => 1;
const our $MAX_WEIGHT => 100;

=pod


=head1 NAME

aotd_selection.pl - Artist Of The Day selection script.


=head1 DESCRIPTION

This cron connects to the database and searches for user accounts that have AOTD tokens.
Then, through a system of weights, it selects one account to be featured as the day's AOTD.
That artist has one AOTD token deducted from their account, and their weight is reset to the highest
weight.  All other weights are reduced by one, unless their weight is already at the lowest point.
Finally, the script sends the selected user a PM and an e-mail to alert them to their front-page status.


=head1 SCHEDULE

Runs every night, at 00:05 ET.


=head1 INVOCATION

    ./aotd_selection.pl

=cut

# Select User
my $user = select_aotd_user();

# Log User in the DB
my $saved = save_new_aotd( $user );

# Adjust all other weights
my $adjusted = adjust_user_weights( $user );

# PM & Email the User
my $notified = notify_the_user( $user );

# Audit log
my $audit_msg = 'Successfully chose today\'s Featured Artist<br>';
$audit_msg   .= sprintf( 'Chosen member is: %s (%s)<br>', $user->account->full_name, $user->username );
$audit_msg   .= sprintf( 'Adjusted %d user weights.<br>', $adjusted );

my $audit_log = Side7::AuditLog->new(
                                        title       => 'Featured Artist Chosen',
                                        user_id     => 0,
                                        affected_id => $user->id,
                                        description => $audit_msg,
                                        ip_address  => 'Internal System',
                                        timestamp   => DateTime->now(),
                                    );
$audit_log->save();

# FUNCTIONS

sub select_aotd_user
{
    my $user = undef;
    foreach my $weight ( $MIN_WEIGHT .. $MAX_WEIGHT )
    {
        my $count = Side7::User::Manager->get_users_count(
                                                            with_objects => [ 'account' ],
                                                            query => [
                                                                        't2.aotd_tokens'    => { gt => 0 },
                                                                        't2.aotd_weight'    => $weight,
                                                                        't2.user_status_id' => 2,
                                                                     ],
                                                         );

        next if $count == 0;

        $user = Side7::User::Manager->get_users(
                                                    with_objects => [ 'account' ],
                                                    query => [
                                                                't2.aotd_tokens'    => { gt => 0 },
                                                                't2.aotd_weight'    => $weight,
                                                                't2.user_status_id' => 2,
                                                             ],
                                                    sort_by => 'RAND()',
                                                    limit   => 1,
                                                );

        last;
    }

    if ( ! defined $user->[0] || ref( $user->[0] ) ne 'Side7::User' )
    {
        $LOGGER->error( 'Failed to find valid User for AOTD.' );
        croak( 'Failed to find valid User for AOTD.' );
    }

    $LOGGER->info( sprintf( 'Selected >%s (%s)< (ID: %d) as today\'s AOTD.',
                                $user->[0]->account->full_name, $user->[0]->username, $user->[0]->id ) );

    #say sprintf( 'DEBUG: Found User: %s (%s) (ID: %d)', $user->[0]->account->full_name, $user->[0]->username, $user->[0]->id );
    #say sprintf( 'DEBUG: Original User Stats: t: %d  w: %d', $user->[0]->account->aotd_tokens, $user->[0]->account->aotd_weight );

    return $user->[0];
}

sub save_new_aotd
{
    my ( $user ) = @_;

    if ( ! defined $user || ref( $user ) ne 'Side7::User' )
    {
        $LOGGER->error( 'Invalid User object passed in while trying to save AOTD record.' );
        croak( 'Invalid User object when saving AOTD record.' );
    }

    my $aotd = Side7::User::AOTD->new( user_id => $user->id, date => DateTime->today() );
    $aotd->save || croak( 'Failed to save AOTD record.' );

    return 1;
}

sub adjust_user_weights
{
    my ( $user ) = @_;

    # Adjust chosen User's weight back to MAX_WEIGHT.
    $user->account->aotd_tokens( $user->account->aotd_tokens - 1);
    $user->account->aotd_weight( $MAX_WEIGHT );
    $user->account->save || croak( 'Failed to save updated User weight and token count.' );

    #say sprintf( 'DEBUG: Updated User Stats: t: %d  w: %d', $user->account->aotd_tokens, $user->account->aotd_weight );

    # Adjust all other Users' weights to n - 1, unless they're 1 already.
    my $updated_accounts = Side7::Account::Manager->update_accounts(
                                                                set =>
                                                                {
                                                                    aotd_weight => \q(aotd_weight - 1),
                                                                },
                                                                where =>
                                                                [
                                                                    user_status_id => 2,
                                                                    aotd_tokens    => { gt => 0 },
                                                                    aotd_weight    => { ne => 1 },
                                                                    user_id        => { ne => $user->id },
                                                                ],
                                                             );

    #say sprintf( 'DEBUG: Updated %d other accounts.', $updated_accounts );

    return $updated_accounts;
}

sub notify_the_user
{
    my ( $user ) = @_;

    my $template_config = {
                            INCLUDE_PATH => "$FindBin::Bin/../views/",
                          };

    my $template = Template->new( $template_config ) || croak $Template::ERROR, "\n";

    my $pm_body    = '';
    my $email_body = '';

    my $vars = {
                user => $user,
               };

    $template->process( 'pm_notifications/aotd_notification.tt', $vars, \$pm_body ) || croak $template->error(), "\n";
    $template->process( 'email/aotd_notification.tt', $vars, \$email_body )         || croak $template->error(), "\n";

    my $pm = Side7::PrivateMessage->new(
                                        sender_id    => 0,
                                        recipient_id => $user->id,
                                        subject      => 'You are the Front Page Featured Artist!',
                                        body         => $pm_body,
                                        status       => 'Delivered',
                                        created_at   => DateTime->now(),
                                       );

    $pm->save;

    my $email = Email::Simple->create(
                                        header => [
                                                    To      => sprintf( '"%s" <%s>', $user->account->full_name, $user->email_address ),
                                                    From    => 'Oni (Side 7) <system@side7.com>',
                                                    Subject => 'You are the Front Page Featured Artist!',
                                                  ],
                                        body   => $email_body,
                                     );
    Email::Sender::Simple->try_to_send( $email )
        || carp( sprintf( 'Could not send notification e-mail to %s at %s.', $user->account->full_name, $user->email_address ) );

    return 1;
}
