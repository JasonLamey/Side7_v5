package Side7;

use strict;
use Mojo::Base 'Mojolicious';
use Mojolicious::Routes::Pattern;
use Mojolicious::Validator;
use Data::Dumper;

use Side7::Globals;
use Side7::DB;
use Side7::Login;
use Side7::User;
use Side7::Account;

=pod

=head1 NAME

Side7

=head1 DESCRIPTION

Primary library for the Side7 app.

=cut

# This method will run once at server start
sub startup {
    my $self = shift;

    # Plugins
    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    # Form Validation plugin
    $self->plugin('ValidateTiny');

    # Signed cookie secret
    $self->secret('Stff.TatvotssE.');

    # Parameter validation
    $self->validator;

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->any( '/' )
        ->to( 'pages#main_page' )
        ->name( 'index' );

    # Sign-up routes
    $r->get( '/signup' )
        ->to( 'user#signup_form' )
        ->name( 'signup_form' );

    $r->post( '/signup' )
        ->to( 'user#process_signup' )
        ->name( 'do_signup' );

    # Login routes
    $r->get( '/login' )
        ->to( 'login#login_form' )
        ->name( 'login_form' );

    $r->post( '/do_login' )
        ->to( 'login#user_login' )
        ->name( 'do_login' );

    # Logout route
    $r->get( '/logout' )
        ->to( 'login#logout' )
        ->name( 'logout' );

    # Routes NOT requiring login
    # Public User Pages
    # User Profile Page
    $r->get( '/user/:username' )
        ->to( 'user#show_profile' )
        ->name( 'show_user_profile' );

    #$r->get( '/user/:username' )
        #->to( 'user#show_public_profile' )
        #->name( 'show_user_profile' );

    # Routes requiring login
    #my $logged_in = $r->under->to( 'login#is_logged_in' );
    # User Profile Management
    # User Friends Management

}

=head1 COPYRIGHT

Copyright (C) Side 7 1992 - 2013

=cut

1;
