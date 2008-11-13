# Makefile.PL for Pod::Thread

BEGIN {
    require 5.004;
    eval { require File::Spec };
    if ($@) { die "You need to install the File::Spec module first!\n" }
}

# Use File::Spec to handle paths, for portability.
sub script {
    my @scripts = map { File::Spec->catfile ('scripts', $_) } @_;
    wantarray ? @scripts : join (' ', @scripts);
}

use ExtUtils::MakeMaker;
WriteMakefile (
    NAME          => 'Pod::Thread',
    DISTNAME      => 'Pod-Thread',
    PL_FILES      => { script ('pod2thread.PL', 'pod2thread') },
    EXE_FILES     => [ script ('pod2thread') ],
    PREREQ_PM     => { 'File::Spec' => 0.8, 'Pod::Parser' => 1.13 },
    ($] >= 5.005 ?
     (ABSTRACT    => 'Convert POD data to the HTML macro language thread',
      AUTHOR      => 'Russ Allbery (rra@stanford.edu)') : ()),
    VERSION_FROM  => 'VERSION',
    realclean     => { FILES => scalar script ('pod2thread') }
);
