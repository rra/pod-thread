#!/usr/bin/perl
#
# Basic rendering tests for Pod::Thread.
#
# Copyright 2009, 2013 Russ Allbery <rra@cpan.org>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.

use 5.008;
use strict;
use warnings;

use Test::More tests => 7;

# Test that the module loads.
BEGIN {
    use_ok('Pod::Thread');
}

# Read a section of a test from DATA, terminated by ###.
#
# Returns: The section without the terminating ### as a string
sub read_test_section {
    my $data = q{};
  INPUT:
    while (defined(my $line = <DATA>)) {
        last INPUT if $line eq "###\n";
        $data .= $line;
    }
    return $data;
}

# Read a test fragment from DATA.  Test fragments start with ### and consist
# of an input and an output section, ending with ###.
#
# Returns: A list of the input and output, or an empty list on end of data
sub read_test {
    my ($line, $input, $output);
  DATA:
    while (defined($line = <DATA>)) {
        last DATA if $line eq "###\n";
    }
    if (!defined($line)) {
        return;
    }
    $input  = read_test_section();
    $output = read_test_section();
    return ($input, $output);
}

# Main routine.  Loop while we have input and output.
my $fragment = 1;
while (my ($input, $expected) = read_test()) {
    my $parser = Pod::Thread->new;
    isa_ok($parser, 'Pod::Thread');
    my $seen;
    $parser->output_string(\$seen);
    $parser->parse_string_document($input);
    is($seen, $expected, "Fragment $fragment");
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

###
=head1 Non-numeric =item

=over 2

=item 1Z<>

First item.

=item 2Z<>

Second item.

=back
###
\h2[Non-numeric =item]

\desc[1]
[First item.
]

\desc[2]
[Second item.
]

\signature
###
