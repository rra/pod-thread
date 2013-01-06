#!/usr/bin/perl
#
# Test Perl code for strict, warnings, syntax, and test coverage.
#
# Test coverage checking is disabled unless RRA_MAINTAINER_TESTS is set since
# it takes a long time, is sensitive to the versions of various libraries,
# and will not interfere with functionality.
#
# Written by Russ Allbery <rra@stanford.edu>
#
# The authors hereby relinquish any claim to any copyright that they may have
# in this work, whether granted under contract or by operation of law or
# international treaty, and hereby commit to the public, at large, that they
# shall not, at any time in the future, seek to enforce any copyright in this
# work against any person or entity, or prevent any person or entity from
# copying, publishing, distributing or creating derivative works of this work.

use strict;
use warnings;

use File::Spec;
use Test::More;

# Coverage level achieved.
use constant COVERAGE_LEVEL => 50;

# Non-fuctional, generic tests to skip for test coverage analysis.
use constant COVERAGE_SKIP_TESTS => (
    't/critic.t',       't/minimum-version.t',
    't/pod-coverage.t', 't/pod-spelling.t',
    't/pod.t',          't/synopsis.t',
);

# Skip tests if Test::Strict is not installed.
if (!eval { require Test::Strict }) {
    plan skip_all => 'Test::Strict required to test Perl syntax';

    # Suppress "only used once" warnings.
    $Test::Strict::TEST_SKIP           = [];
    $Test::Strict::TEST_WARNINGS       = 0;
    $Test::Strict::DEVEL_COVER_OPTIONS = q{};
}
Test::Strict->import;

# Test everything in the distribution directory.  We also want to check use
# warnings.
$Test::Strict::TEST_WARNINGS = 1;
all_perl_files_ok();

# Test code coverage.  Skip this test unless we're running the test suite in
# maintainer mode.
SKIP: {
    if (!$ENV{RRA_MAINTAINER_TESTS}) {
        skip 'Coverage test only run for maintainer', 1;
    }
    if (!eval { require Devel::Cover }) {
        skip 'Devel::Cover required to check test coverage', 1;
    }

    # Skip the various generic tests that don't add to coverage.  Some of
    # these load a lot of Perl code, which causes Devel::Cover to be very
    # slow.
    my @skip = map { File::Spec->canonpath($_) } COVERAGE_SKIP_TESTS;
    $Test::Strict::TEST_SKIP = [@skip];

    # Disable POD coverage; that's handled separately and is confused by our
    # autoloading.
    $Test::Strict::DEVEL_COVER_OPTIONS
      = '-coverage,statement,branch,condition,subroutine';
    all_cover_ok(COVERAGE_LEVEL);
}
