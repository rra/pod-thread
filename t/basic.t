#!/usr/bin/perl -w
#
# Basic rendering tests for Pod::Thread.
#
# Copyright 2009, 2013 Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use Test::More tests => 4;

use Pod::Thread;

my $parser = Pod::Thread->new;
ok ($parser, 'Constructor succeeded');
isa_ok ($parser, 'Pod::Thread');
my $fragment = 1;
while (<DATA>) {
    next until $_ eq "###\n";
    open (TMP, '> tmp.pod') or die "Cannot create tmp.pod: $!\n";
    while (<DATA>) {
        last if $_ eq "###\n";
        print TMP $_;
    }
    close TMP;
    open (OUT, '> out.tmp') or die "Cannot create out.tmp: $!\n";
    $parser->parse_from_file ('tmp.pod', \*OUT);
    close OUT;
    open (TMP, 'out.tmp') or die "Cannot open out.tmp: $!\n";
    my $output;
    {
        local $/;
        $output = <TMP>;
    }
    close TMP;
    unlink ('tmp.pod', 'out.tmp');
    my $expected = '';
    while (<DATA>) {
        last if $_ eq "###\n";
        $expected .= $_;
    }
    is ($output, $expected, "Fragment $fragment");
    $fragment++;
}

# Below the marker are bits of POD and corresponding expected text output.
# This is used to test specific features or problems with Pod::Thread.  The
# input and output are separated by lines containing only ###.

__DATA__

###
=head1 ITEM 0

=over 4

=item 0

Some 0 item.

=back
###
\h2[ITEM 0]

\desc[0]
[Some 0 item.
]

\signature
###

###
=head1 URLs

URL with L<anchor text|http://example.com/>.

URL without anchor text: L<http://example.com/>.
###
\h2[URLs]

URL with \link[http://example.com/][anchor text].

URL without anchor text:
<\link[http://example.com/][http://example.com/]>.

\signature
###
