# Makefile.PL for Pod::Thread
#
# Copyright 2002, 2013 Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use 5.008;
use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker;
use File::Spec;

# Return the path to a script.  Use File::Spec to handle paths, for
# portability.
#
# @scripts - All the scripts to qualify with a path
#
# Returns: (array)  An array of the paths to the scripts
#          (scalar) A space-separated string of the paths to the scripts
sub script {
    my (@scripts) = @_;
    @scripts = map { File::Spec->catfile('scripts', $_) } @scripts;
    return wantarray ? @scripts : join q{ }, @scripts;
}

# Determine the path to the set-version script used to update module versions.
my $set_version = File::Spec->catfile(File::Spec->curdir(), 'set-version');

# Ouptut the Makefile.
WriteMakefile(
    NAME         => 'Pod::Thread',
    DISTNAME     => 'Pod-Thread',
    ABSTRACT     => 'Convert POD data to the HTML macro language thread',
    AUTHOR       => 'Russ Allbery <rra@stanford.edu>',
    VERSION_FROM => 'VERSION',

    # Prerequisites and requirements.
    MIN_PERL_VERSION => 5.008,
    PREREQ_PM        => {
        'Pod::Simple' => 3.06,
        'Readonly'    => 0,
    },

    # What to install.
    EXE_FILES => [script('pod2thread')],
    PM_FILTER => "perl $set_version",

    # ExtUtils::MakeMaker only understands this with Perl 5.10 or later.
    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    ($] >= 5.010 ? (LICENSE => 'perl') : ()),
);
