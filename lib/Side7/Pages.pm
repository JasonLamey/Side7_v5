package Side7::Pages;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

=pod

=head1 NAME

Side7::Pages

=head1 DESCRIPTION

This class represents general site page calls.

=head1 METHODS

=head2 method_name

    $result = Side7::Pages->main_page();

Renders the site's main page.

=cut

sub main_page
{
    my $self = shift;

    $self->render();
}

=pod

=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
