# Subclass of Module::Build that sets module versions during build.
#
# This is a small custom subclass of Module::Build that overrides the
# process_pm_files sub to set the $VERSION of each module to match the
# distribution version.  It is based conceptually on Module::Build::PM_Filter,
# but is much simpler since it only takes that one action.
#
# Copyright 2013 Russ Allbery <rra@cpan.org>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

##############################################################################
# Modules and declarations
##############################################################################

package Module::Build::SetVersion;

use 5.010;
use autodie;
use strict;
use warnings;

use Carp qw(croak);
use File::Spec;
use File::Temp;
use Readonly;

use parent qw(Module::Build);

our $VERSION = '1.00';

##############################################################################
# Internal constants
##############################################################################

# Regex matching the line setting $VERSION in a module.
Readonly my $VERSION_REGEX => qr{
    \A (                        # capture the leading text (1)
        \s* (?: our | my ) \s*  #   optional leading our or my
        \$VERSION \s* = \s*     #   $VERSION setting
    )                           # end part being preserved
    '? \S+ '? ;                 # version setting with optional quotes
    \s* \z                      # trailing whitespace
}xms;

##############################################################################
# Implementation
##############################################################################

# Given open input and output file handles, filter the input file to the
# output file, replacing the first instance of the value of $VERSION with the
# dist_version from the module configuration.
#
# $self - The Module::Build object
# $in   - The input file handle
# $out  - The output file handle
#
# Returns: undef
#  Throws: Text or autodie exception on I/O failure
sub _filter_pm_file_version {
    my ($self, $in, $out) = @_;
    my $version = $self->dist_version;

    # Find the first line setting $VERSION and update it.
    while (defined(my $line = <$in>)) {
        if ($line =~ s{ $VERSION_REGEX }{$1'$version';\n}xms) {
            print {$out} $line or croak("Cannot write to output file: $!");
            last;
        }
        print {$out} $line or croak("Cannot write to output file: $!");
    }

    # Copy the remaining input to the output verbatim.
    while (defined(my $line = <$in>)) {
        print {$out} $line or croak("Cannot write to output file: $!");
    }

    # Flush output before returning since we're about to copy the file.
    $out->flush;
    return;
}

# A replacement for the default process_pm_files Module::Build method that
# sets the version number of each file to match the dist_version.
#
# $self - The Module::Build object
# $ext  - The extension of the *.pm files
#
# Returns: undef
#  Throws: autodie exception on I/O failure
sub process_pm_files {
    my ($self, $ext) = @_;

    # Build the method for finding the files.
    my $method = "find_${ext}_files";
    my $files;
    if ($self->can($method)) {
        $files = $self->$method;
    } else {
        $files = $self->_find_file_by_type($ext, 'lib');
    }

    # Iterate through each file and filter it if out of date.
    while (my ($file, $dest) = each %{$files}) {
        my $path = File::Spec->catfile($self->blib, $dest);
        if (!$self->up_to_date($file, $path)) {
            open(my $in, q{<}, $file);
            my $temp = File::Temp->new;
            $self->_filter_pm_file_version($in, $temp);
            close($in);
            $self->copy_if_modified(from => $temp->filename, to => $path);
        }
    }
    return;
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery Readonly CPAN metadata subclasses

=head1 NAME

Module::Build::SetVersion - Subclass Module::Build to set module version

=head1 SYNOPSIS

    use Module::Build::SetVersion;

    my $build = Module::Build::SetVersion->new(
        module_name => 'Foo::Bar',
        # ... all the usual arguments ...
        dist_version => '1.03',
    );
    $build->create_build_script;

=head1 REQUIREMENTS

Perl 5.10.1 or later, the Readonly Perl module (available from CPAN),
and Module::Build.  This subclass does use a small number of internal
Module::Build interfaces, and therefore may need porting to later
versions of Module::Build.

=head1 DESCRIPTION

This module subclasses Module::Build and overrides the treatment of
Perl modules (files ending in F<.pm>) to replace any lines setting the
module $VERSION variable to use the dist_version declared in the
module metadata.  All other Module::Build operations work as normal.

To use this subclass, ensure that dist_version is set in the arguments
to the Module::Build constructor and then just use this class as you
would use Module::Build.  During the module build process, any module
files will be filtered looking for lines that set the $VERSION variable.
For each module, the first such line found will have its value replaced
with the dist_version metadata value.

=head1 METHODS

=over 4

=item process_pm_files(EXT)

This is the only standard Module::Build method overridden.  Rather than
only copy changed files into the F<blib> tree, it filters changed module
files to replace the version as described above.

=back

=head1 AUTHOR

Russ Allbery <rra@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright 2013 Russ Allbery <rra@cpan.org>

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Module::Build>.

This module was inspired by L<Module::Build::PM_Filter>, but does much less
than that module can do.

=cut
