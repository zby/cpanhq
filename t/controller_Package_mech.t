#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use Test::WWW::Mechanize::Catalyst 'CPANHQ';

{
    my $mech = Test::WWW::Mechanize::Catalyst->new;

    # TEST
    $mech->get_ok("http://localhost:3000/package/WiX3::Exceptions");
    
    # TEST
#    $mech->html_lint_ok("/package page validates");
}

done_testing;

=head1 AUTHOR

Zbigniew Łukasiak L<http://zbigniew.lukasiak.name/> .

=head1 LICENSE

This module is free software, available under the MIT X11 Licence:

L<http://www.opensource.org/licenses/mit-license.php>

Copyright by Zbigniew Łukasiak, 2009.

=cut

