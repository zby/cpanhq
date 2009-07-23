#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;

use Test::WWW::Mechanize::Catalyst 'CPANHQ';

{
    my $mech = Test::WWW::Mechanize::Catalyst->new;

    # TEST
    $mech->get_ok("http://localhost/status/");

    # TEST
    $mech->html_lint_ok("/status/ validates.");

    # TEST
    $mech->follow_link_ok(
        {
            text_regex => qr{Specific version of a release},
        },
        "Following the link to the release works."
    );

    # TEST
    $mech->html_lint_ok("The specific version link validates.");    
}

=head1 AUTHOR

Shlomi Fish L<http://www.shlomifish.org/> .

=head1 LICENSE

This module is free software, available under the MIT X11 Licence:

L<http://www.opensource.org/licenses/mit-license.php>

Copyright by Shlomi Fish, 2009.

=cut

