#!/usr/local/bin/perl

use Config;
use File::Basename qw(&basename &dirname);
use Cwd;

# List explicitly here the variables you want Configure to
# generate.  Metaconfig only looks for shell variables, so you
# have to mention them as if they were shell variables, not
# %Config entries.  Thus you write
#  $startperl
# to ensure Configure will look for $Config{startperl}.

# This forces PL files to create target in same directory as PL file.
# This is so that make depend always knows where to find PL derivatives.
$origdir = cwd;
chdir dirname($0);
$file = basename($0, '.PL');
$file .= '.com' if $^O eq 'VMS';

open OUT,">$file" or die "Can't create $file: $!";

print "Extracting $file (with variable substitutions)\n";

# In this section, perl variables will be expanded during extraction.
# You can use $Config{...} to use Configure variables.

print OUT <<"!GROK!THIS!";
$Config{startperl}
    eval 'exec $Config{perlpath} -S \$0 \${1+"\$@"}'
        if \$running_under_some_shell;
!GROK!THIS!

# In the following, perl variables are not expanded during extraction.

print OUT <<'!NO!SUBS!';

# pod2thread -- Convert POD data to the HTML macro language thread.
# $Id: pod2thread.PL,v 1.2 2002-06-29 22:13:43 eagle Exp $
#
# Copyright 2002 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.
#
# The driver script for Pod::Thread.

require 5.004;

use Getopt::Long qw(GetOptions);
use Pod::Thread ();

use strict;

# Silence -w warnings.
use vars qw($running_under_some_shell);

# Insert -- into @ARGV before any single dash argument to hide it from
# Getopt::Long; we want to interpret it as meaning stdin (which Pod::Parser
# does correctly).
my $stdin;
@ARGV = map { $_ eq '-' && !$stdin++ ? ('--', $_) : $_ } @ARGV;

# Parse our options.  Use the same names as Pod::Text for simplicity, and
# default to sentence boundaries turned off for compatibility.
my %options;
Getopt::Long::config ('bundling');
GetOptions (\%options, 'help|h', 'style|s=s') or exit 1;
pod2usage (1) if $options{help};

# Initialize and run the formatter.
my $parser = Pod::Thread->new (%options);
$parser->parse_from_file (@ARGV);

__END__

=head1 NAME

pod2thread - Convert POD data to the HTML macro language thread.

=head1 SYNOPSIS

pod2thread [B<-h>] [B<-s> I<style>] [I<input> [I<output>]]

=head1 DESCRIPTION

B<pod2thread> is a front-end for Pod::Thread and its subclasses.  It uses
that module to generate thread source from POD source.

I<input> is the file to read for POD source (the POD can be embedded in
code).  If I<input> isn't given, it defaults to STDIN.  I<output>, if given,
is the file to which to write the thread output.  If I<output> isn't given,
the output is written to STDOUT.

=head1 OPTIONS

=over 4

=item B<-h>, B<--help>

Print out usage information and exit.

=item B<-s> I<style>, B<--style>=I<style>

In the generated thread source, include a reference to the style sheet
I<style>.  If this option is not given, no style sheet reference will be
included.

=back

=head1 DIAGNOSTICS

If B<pod2thread> fails with errors, see L<Pod::Thread> and L<Pod::Parser>
for information about what those errors might mean.  Internally, it can also
produce the following diagnostic:

=over 4

=item Unknown option: %s

(F) An unknown command line option was given.

=back

In addition, other L<Getopt::Long> error messages may result from invalid
command-line options.

=head1 SEE ALSO

L<Pod::Thread>, L<Pod::Parser>, spin(1)

Current versions of this program are available from my web tools page at
L<http://www.eyrie.org/~eagle/software/web/>.  B<spin> is available from the
same page.

=head1 AUTHOR

Russ Allbery <rra@stanford.edu>.

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Russ Allbery <rra@stanford.edu>.

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=cut
!NO!SUBS!

close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
exec("$Config{'eunicefix'} $file") if $Config{'eunicefix'} ne ':';
chdir $origdir;
