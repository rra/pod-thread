#!/usr/bin/perl
#
# Check for spelling errors in POD documentation.
#
# Checks all POD files in a Perl distribution using Test::Spelling.  This test
# is disabled unless RRA_MAINTAINER_TESTS is set, since spelling dictionaries
# vary too much between environments.
#
# The canonical version of this file is maintained in the rra-c-util package,
# which can be found at <http://www.eyrie.org/~eagle/software/rra-c-util/>.
#
# Written by Russ Allbery <rra@stanford.edu>
# Copyright 2013
#     The Board of Trustees of the Leland Stanford Junior University
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

use 5.006;
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Test::RRA qw(skip_unless_maintainer use_prereq);

# Only run this test for the maintainer.
skip_unless_maintainer('Spelling tests');

# Load prerequisite modules.
use_prereq('Test::Spelling');

# Check all POD in the Perl distribution.  Add the examples and tools
# directories if they exist.  Also add any files in usr/bin or usr/sbin, which
# are widely used in Stanford-internal packages.
my @files = all_pod_files();
for my $path (qw(examples tools)) {
    if (-d $path) {
        push(@files, all_pod_files($path));
    }
}
for my $dir (qw(usr/bin usr/sbin)) {
    if (-d $dir) {
        push(@files, glob("$dir/*"));
    }
}

# We now have a list of all files to check, so output a plan and run the
# tests.  We can't use all_pod_files_spelling_ok because it refuses to check
# non-Perl files and Stanford-internal packages have a lot of shell scripts
# with POD documentation.
plan tests => scalar(@files);
for my $file (@files) {
    pod_file_spelling_ok($file);
}