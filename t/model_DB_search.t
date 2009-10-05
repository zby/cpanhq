#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use Catalyst::Test 'CPANHQ';

use CPANHQ;
use CPANHQ::Storage;

use DateTime;

{
    my $schema = CPANHQ->model("DB");

    my $package_rs = $schema->resultset('Package');

    is( $package_rs->xsearch( { query => 'catalyst' } )->count, 940, "Catalyst matches" );
    is( $package_rs->xsearch( { 'author.cpanid' => 'ADAMK' } )->count, 598, "Adam's packages" );
    is( $package_rs->xsearch( { 'author.cpanid' => 'ADAMK', query => 'catalyst' } )->count, 2, "Adam's packages matching catalyst" );
}

done_testing;
