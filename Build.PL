#!/usr/bin/perl
#
# Build script for Pod::Thread distribution.
#
# Copyright 2002, 2013, 2021 Russ Allbery <rra@cpan.org>
#
# SPDX-License-Identifier: MIT

use 5.008;
use strict;
use warnings;

use lib 'tools/lib';

use Module::Build::SetVersion;

# Basic package configuration.
my $build = Module::Build::SetVersion->new(
    module_name          => 'Pod::Thread',
    dist_abstract        => 'Convert POD data to thread HTML macro language',
    dist_author          => 'Russ Allbery <rra@cpan.org>',
    dist_version         => '1.01',
    license              => 'perl',
    recursive_test_files => 1,
    create_makefile_pl   => 'traditional',

    # Other package relationships.
    configure_requires => { 'Module::Build' => 0.28 },
    requires           => {
        'Pod::Simple' => 3.06,
        perl          => '5.008',
    },
);

# Generate the build script.
$build->create_build_script;
