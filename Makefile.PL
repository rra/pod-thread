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

WriteMakefile(
    NAME         => 'Pod::Thread',
    DISTNAME     => 'Pod-Thread',
    ABSTRACT     => 'Convert POD data to the HTML macro language thread',
    AUTHOR       => 'Russ Allbery <rra@stanford.edu>',
    VERSION_FROM => 'VERSION',
    EXE_FILES    => [script('pod2thread')],
    PREREQ_PM    => {
        'File::Spec'  => 0.8,
        'Pod::Simple' => 3.06,
        'Readonly'    => 0,
    },
);
