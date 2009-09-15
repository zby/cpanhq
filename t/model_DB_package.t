#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;

use Catalyst::Test 'CPANHQ';

use CPANHQ;
use CPANHQ::Storage;
use File::Spec;

use DateTime;

{
    my $schema = CPANHQ->model("DB");

    my $packages_rs = $schema->resultset('Package');

    my $test_count_pkg = $packages_rs->find({name => "Test::Count"});

    # TEST
    ok ($test_count_pkg, "Test::Count package is available.");

    # TEST
    is(
        $test_count_pkg->get_html_path(),
        File::Spec->catfile(
            CPANHQ->config->{'archive_extract_path'},
            qw(Test-Count-0.0500 lib Test Count.pm),
        ),
        "HTML Path for Test::Count is OK.",
    );

}

