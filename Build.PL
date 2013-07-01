#!/usr/bin/perl
#
# Build script for Pod::Thread distribution.
#
# Copyright 2002, 2013 Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use 5.008;
use strict;
use warnings;

use lib 'tools/lib';

use Module::Build::SetVersion;

# Basic package configuration.
my $build = Module::Build::SetVersion->new(
    module_name          => 'Pod::Thread',
    dist_abstract        => 'Convert POD data to thread HTML macro language',
    dist_author          => 'Russ Allbery <rra@stanford.edu>',
    dist_version         => '1.01',
    license              => 'perl',
    recursive_test_files => 1,
    create_makefile_pl   => 'traditional',

    # Other package relationships.
    configure_requires => { 'Module::Build' => 0.28 },
    requires           => {
        'Pod::Simple' => 3.06,
        'Readonly'    => 0,
        perl          => '5.008',
    },
);

# Generate the build script.
$build->create_build_script;
