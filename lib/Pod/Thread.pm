# Pod::Thread -- Convert POD data to the HTML macro language thread.
# $Id: Thread.pm,v 0.3 2002-06-28 20:05:44 eagle Exp $
#
# Copyright 2002 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.
#
# This module converts POD to the HTML macro language thread.  It's intended
# for use with the spin program to include POD documentation in a
# spin-generated web page complex.

##############################################################################
# Modules and declarations
##############################################################################

package Pod::Thread;

require 5.004;

use Carp qw(carp croak);
use Pod::ParseLink qw(parselink);
use Pod::Parser ();

use strict;
use vars qw(@ISA %ESCAPES $VERSION);

@ISA = qw(Pod::Parser);

# Don't use the CVS revision as the version, but the version should match the
# CVS revision.
$VERSION = 0.03;

##############################################################################
# Table of supported E<> escapes
##############################################################################

# This table is taken near verbatim from Pod::PlainText in Pod::Parser, which
# got it near verbatim from the original Pod::Text.  It is therefore credited
# to Tom Christiansen, and I'm glad I didn't have to write it.  :)  "iexcl" to
# "divide" added by Tim Jenness.
%ESCAPES = (
    'amp'       =>    '&',      # ampersand
    'apos'      =>    "'",      # apostrophe
    'lt'        =>    '<',      # left chevron, less-than
    'gt'        =>    '>',      # right chevron, greater-than
    'quot'      =>    '"',      # double quote
    'sol'       =>    '/',      # solidus (forward slash)
    'verbar'    =>    '|',      # vertical bar

    "Aacute"    =>    "\xC1",   # capital A, acute accent
    "aacute"    =>    "\xE1",   # small a, acute accent
    "Acirc"     =>    "\xC2",   # capital A, circumflex accent
    "acirc"     =>    "\xE2",   # small a, circumflex accent
    "AElig"     =>    "\xC6",   # capital AE diphthong (ligature)
    "aelig"     =>    "\xE6",   # small ae diphthong (ligature)
    "Agrave"    =>    "\xC0",   # capital A, grave accent
    "agrave"    =>    "\xE0",   # small a, grave accent
    "Aring"     =>    "\xC5",   # capital A, ring
    "aring"     =>    "\xE5",   # small a, ring
    "Atilde"    =>    "\xC3",   # capital A, tilde
    "atilde"    =>    "\xE3",   # small a, tilde
    "Auml"      =>    "\xC4",   # capital A, dieresis or umlaut mark
    "auml"      =>    "\xE4",   # small a, dieresis or umlaut mark
    "Ccedil"    =>    "\xC7",   # capital C, cedilla
    "ccedil"    =>    "\xE7",   # small c, cedilla
    "Eacute"    =>    "\xC9",   # capital E, acute accent
    "eacute"    =>    "\xE9",   # small e, acute accent
    "Ecirc"     =>    "\xCA",   # capital E, circumflex accent
    "ecirc"     =>    "\xEA",   # small e, circumflex accent
    "Egrave"    =>    "\xC8",   # capital E, grave accent
    "egrave"    =>    "\xE8",   # small e, grave accent
    "ETH"       =>    "\xD0",   # capital Eth, Icelandic
    "eth"       =>    "\xF0",   # small eth, Icelandic
    "Euml"      =>    "\xCB",   # capital E, dieresis or umlaut mark
    "euml"      =>    "\xEB",   # small e, dieresis or umlaut mark
    "Iacute"    =>    "\xCD",   # capital I, acute accent
    "iacute"    =>    "\xED",   # small i, acute accent
    "Icirc"     =>    "\xCE",   # capital I, circumflex accent
    "icirc"     =>    "\xEE",   # small i, circumflex accent
    "Igrave"    =>    "\xCC",   # capital I, grave accent
    "igrave"    =>    "\xEC",   # small i, grave accent
    "Iuml"      =>    "\xCF",   # capital I, dieresis or umlaut mark
    "iuml"      =>    "\xEF",   # small i, dieresis or umlaut mark
    "Ntilde"    =>    "\xD1",   # capital N, tilde
    "ntilde"    =>    "\xF1",   # small n, tilde
    "Oacute"    =>    "\xD3",   # capital O, acute accent
    "oacute"    =>    "\xF3",   # small o, acute accent
    "Ocirc"     =>    "\xD4",   # capital O, circumflex accent
    "ocirc"     =>    "\xF4",   # small o, circumflex accent
    "Ograve"    =>    "\xD2",   # capital O, grave accent
    "ograve"    =>    "\xF2",   # small o, grave accent
    "Oslash"    =>    "\xD8",   # capital O, slash
    "oslash"    =>    "\xF8",   # small o, slash
    "Otilde"    =>    "\xD5",   # capital O, tilde
    "otilde"    =>    "\xF5",   # small o, tilde
    "Ouml"      =>    "\xD6",   # capital O, dieresis or umlaut mark
    "ouml"      =>    "\xF6",   # small o, dieresis or umlaut mark
    "szlig"     =>    "\xDF",   # small sharp s, German (sz ligature)
    "THORN"     =>    "\xDE",   # capital THORN, Icelandic
    "thorn"     =>    "\xFE",   # small thorn, Icelandic
    "Uacute"    =>    "\xDA",   # capital U, acute accent
    "uacute"    =>    "\xFA",   # small u, acute accent
    "Ucirc"     =>    "\xDB",   # capital U, circumflex accent
    "ucirc"     =>    "\xFB",   # small u, circumflex accent
    "Ugrave"    =>    "\xD9",   # capital U, grave accent
    "ugrave"    =>    "\xF9",   # small u, grave accent
    "Uuml"      =>    "\xDC",   # capital U, dieresis or umlaut mark
    "uuml"      =>    "\xFC",   # small u, dieresis or umlaut mark
    "Yacute"    =>    "\xDD",   # capital Y, acute accent
    "yacute"    =>    "\xFD",   # small y, acute accent
    "yuml"      =>    "\xFF",   # small y, dieresis or umlaut mark

    "laquo"     =>    "\xAB",   # left pointing double angle quotation mark
    "lchevron"  =>    "\xAB",   #  synonym (backwards compatibility)
    "raquo"     =>    "\xBB",   # right pointing double angle quotation mark
    "rchevron"  =>    "\xBB",   #  synonym (backwards compatibility)

    "iexcl"     =>    "\xA1",   # inverted exclamation mark
    "cent"      =>    "\xA2",   # cent sign
    "pound"     =>    "\xA3",   # (UK) pound sign
    "curren"    =>    "\xA4",   # currency sign
    "yen"       =>    "\xA5",   # yen sign
    "brvbar"    =>    "\xA6",   # broken vertical bar
    "sect"      =>    "\xA7",   # section sign
    "uml"       =>    "\xA8",   # diaresis
    "copy"      =>    "\xA9",   # Copyright symbol
    "ordf"      =>    "\xAA",   # feminine ordinal indicator
    "not"       =>    "\xAC",   # not sign
    "shy"       =>    '',       # soft (discretionary) hyphen
    "reg"       =>    "\xAE",   # registered trademark
    "macr"      =>    "\xAF",   # macron, overline
    "deg"       =>    "\xB0",   # degree sign
    "plusmn"    =>    "\xB1",   # plus-minus sign
    "sup2"      =>    "\xB2",   # superscript 2
    "sup3"      =>    "\xB3",   # superscript 3
    "acute"     =>    "\xB4",   # acute accent
    "micro"     =>    "\xB5",   # micro sign
    "para"      =>    "\xB6",   # pilcrow sign = paragraph sign
    "middot"    =>    "\xB7",   # middle dot = Georgian comma
    "cedil"     =>    "\xB8",   # cedilla
    "sup1"      =>    "\xB9",   # superscript 1
    "ordm"      =>    "\xBA",   # masculine ordinal indicator
    "frac14"    =>    "\xBC",   # vulgar fraction one quarter
    "frac12"    =>    "\xBD",   # vulgar fraction one half
    "frac34"    =>    "\xBE",   # vulgar fraction three quarters
    "iquest"    =>    "\xBF",   # inverted question mark
    "times"     =>    "\xD7",   # multiplication sign
    "divide"    =>    "\xF7",   # division sign

    "nbsp"      =>    ' ',      # non-breaking space
);

##############################################################################
# Initialization
##############################################################################

# Tell Pod::Parser that we want to see everything, not just the POD (so that
# we can search for Id strings).
sub initialize {
    my $self = shift;
    $self->SUPER::initialize;
    $self->parseopts ('-want_nonPODs' => 1);
}

##############################################################################
# Core overrides
##############################################################################

# Called for each command paragraph.  Gets the command, the associated
# paragraph, the line number, and a Pod::Paragraph object.  Just dispatches
# the command to a method named the same as the command.  =cut is handled
# internally by Pod::Parser.
sub command {
    my $self = shift;
    my $command = shift;
    return if $command eq 'pod';
    return if ($$self{EXCLUDE} && $command ne 'end');
    if ($self->can ('cmd_' . $command)) {
        $command = 'cmd_' . $command;
        $self->$command (@_);
    } else {
        my ($text, $line, $paragraph) = @_;
        my $file;
        ($file, $line) = $paragraph->file_line;
        $text =~ s/\n+\z//;
        $text = " $text" if ($text =~ /^\S/);
        warn qq($file:$line: Unknown command paragraph: =$command$text\n);
        return;
    }
}

# Called for a verbatim paragraph.  Gets the paragraph, the line number, and a
# Pod::Paragraph object.  Just output it verbatim, but with tabs converted to
# spaces.
sub verbatim {
    my $self = shift;
    return if $$self{EXCLUDE};
    local $_ = shift;
    return if /^\s*$/;
    s/^(\s*\S+)/$1/gme;
    s/(\n+)$/\]$1/;
    if ($$self{ITEMS} && @{ $$self{ITEMS} } > 0) {
        $self->item ("\\pre\n[" . $_);
    } else {
        $self->output ("\\pre\n[" . $_);
    }
}

# Called for a regular text block.  Gets the paragraph, the line number, and a
# Pod::Paragraph object.  Perform interpolation and output the results.
sub textblock {
    my $self = shift;
    return if $$self{EXCLUDE};
    $self->output ($_[0]), return if $$self{VERBATIM};
    local $_ = shift;
    my $line = shift;

    # Interpolate and output the paragraph.
    $_ = $self->interpolate ($_, $line);
    s/\s+$/\n/;
    if ($$self{ITEMS} && @{ $$self{ITEMS} } > 0) {
        $self->item ($self->reformat ($_));
    } elsif ($$self{IN_NAME} && /(\S+) - (.*)/) {
        my ($name, $description) = ($1, $2);
        $self->output ("\\id[$$self{ID}]\n\n");
        $self->output ("\\heading[$name][$$self{style}]\n\n");
        $self->output ("\\h1[$name]\n\n\\p(subhead)[($description)]\n\n");
    } else {
        $self->output ($self->reformat ($_ . "\n"));
    }
}

# Called for a formatting code.  Gets the command, argument, and a
# Pod::InteriorSequence object and is expected to return the resulting text.
# Calls methods for code, bold, italic, file, and link to handle those types
# of codes, and handles S<>, E<>, X<>, and Z<> directly.
sub interior_sequence {
    local $_;
    my ($self, $command, $seq);
    ($self, $command, $_, $seq) = @_;

    # We have to defer processing of the inside of an L<> formatting code.  If
    # this code is nested inside an L<> code, return the literal raw text of
    # it.
    my $parent = $seq->nested;
    while (defined $parent) {
        return $seq->raw_text if ($parent->cmd_name eq 'L');
        $parent = $parent->nested;
    }

    # Index entries are ignored in plain text.
    return '' if ($command eq 'X' || $command eq 'Z');

    # Expand escapes into the actual character now, warning if invalid.
    if ($command eq 'E') {
        if (/^\d+$/) {
            return chr;
        } else {
            return $ESCAPES{$_} if defined $ESCAPES{$_};
            my ($file, $line) = $seq->file_line;
            warn "$file:$line: Unknown escape: E<$_>\n";
            return "E<$_>";
        }
    }

    # For all the other formatting codes, empty content produces no output.
    return if $_ eq '';

    # We don't support S<> yet.
    return $_ if ($command eq 'S');

    # Anything else needs to get dispatched to another method.
    if    ($command eq 'B') { return $self->seq_b ($_) }
    elsif ($command eq 'C') { return $self->seq_c ($_) }
    elsif ($command eq 'F') { return $self->seq_f ($_) }
    elsif ($command eq 'I') { return $self->seq_i ($_) }
    elsif ($command eq 'L') { return $self->seq_l ($_, $seq) }
    else {
        my ($file, $line) = $seq->file_line;
        warn "$file:$line: Unknown formatting code: $command<$_>\n";
    }
}

# Called for each paragraph that's actually part of the POD.  We take
# advantage of this opportunity to untabify the input and double any
# pre-existing backslashes in the input.  Also pick up the Id string if we
# find it.
sub preprocess_paragraph {
    my $self = shift;
    local $_ = shift;
    1 while s/^(.*?)(\t+)/$1 . ' ' x (length ($2) * 8 - length ($1) % 8)/me;
    s/\\/\\\\/g;
    $$self{ID} = $1 if (/(\$Id\:.*\$)/);
    $_;
}

# Tack the \signature on to the end.
sub end_pod {
    my $self = shift;
    $self->output ("\\signature\n");
}

##############################################################################
# Command paragraphs
##############################################################################

# All command paragraphs take the paragraph and the line number.

# First level heading.
sub cmd_head1 {
    my ($self, $text, $line) = @_;
    $text =~ s/\s+$//;
    if ($text eq 'NAME') {
        $$self{IN_NAME} = 1;
    } else {
        $self->heading ($text, 2, $line);
    }
}

# Second level heading.
sub cmd_head2 {
    my ($self, $text, $line) = @_;
    $self->heading ($text, 3, $line);
}

# Third level heading.
sub cmd_head3 {
    my ($self, $text, $line) = @_;
    $self->heading ($text, 4, $line);
}

# Third level heading.
sub cmd_head4 {
    my ($self, $text, $line) = @_;
    $self->heading ($text, 5, $line);
}

# Start a list.
sub cmd_over {
    my $self = shift;
    local $_ = shift;
    if ($$self{PENDING}) {
        $self->output ("]\n");
        $$self{PENDING} = 0;
    }
    $$self{LEVEL}++;
    $$self{ITEMS} ||= [];
    unshift (@{ $$self{ITEMS} }, '');
}

# End a list.
sub cmd_back {
    my ($self, $text, $line, $paragraph) = @_;
    if ($$self{WAITING}) { $self->item }
    if ($$self{PENDING}) {
        $self->output ("]\n");
        $$self{PENDING} = 0;
    }
    $$self{LEVEL}--;
    if ($$self{LEVEL} < 0) {
        my $file;
        ($file, $line) = $paragraph->file_line;
        warn "$file:$line: Unmatched =back\n";
        $$self{LEVEL} = 0;
    } else {
        shift @{ $$self{ITEMS} };
    }
}

# An individual list item.
sub cmd_item {
    my $self = shift;
    if ($$self{WAITING}) { $self->item }
    local $_ = shift;
    s/\s+$//;
    $_ ||= '*';
    $_ = $self->interpolate ($_);
    if ($_ eq '*') {
        $$self{ITEMS}[0] = '\\bullet';
    } elsif (/^(\d+)[.\)]?\s*$/) {
        $$self{ITEMS}[0] = '\\number';
    } else {
        $$self{ITEMS}[0] = '\\desc[' . $_ . ']';
    }
    $$self{WAITING} = 1;
}

# Begin a block for a particular translator.  Setting VERBATIM triggers
# special handling in textblock().
sub cmd_begin {
    my $self = shift;
    local $_ = shift;
    my ($kind) = /^(\S+)/ or return;
    if ($kind eq 'thread') {
        $$self{VERBATIM} = 1;
    } else {
        $$self{EXCLUDE} = 1;
    }
}

# End a block for a particular translator.  We assume that all =begin/=end
# pairs are properly closed.
sub cmd_end {
    my $self = shift;
    $$self{EXCLUDE} = 0;
    $$self{VERBATIM} = 0;
}

# One paragraph for a particular translator.  Ignore it unless it's intended
# for thread, in which case we output it verbatim.
sub cmd_for {
    my $self = shift;
    local $_ = shift;
    my $line = shift;
    return unless s/^thread\b[ \t]*\n?//;
    $self->output ($_);
}

##############################################################################
# Formatting codes
##############################################################################

# The simple ones.  These are here mostly so that subclasses can override them
# and do more complicated things.
sub seq_c { return "\\code[$_[1]]" }
sub seq_b { return "\\bold[$_[1]]" }
sub seq_f { return "\\italic[$_[1]]" }
sub seq_i { return "\\italic[$_[1]]" }

# Handle links.  Don't try to actually generate hyperlinks for anything other
# than normal URLs at least at present.  Most of the work is done by
# Pod::ParseLink.
sub seq_l {
    my ($self, $link, $seq) = @_;
    my ($text, $type) = (parselink ($link))[1,4];
    my ($file, $line) = $seq->file_line;
    $text = $self->interpolate ($text, $line);
    $text = '<\\link[' . $text . '][' . $text . ']>' if $type eq 'url';
    return $text || '';
}

##############################################################################
# Header handling
##############################################################################

# The common code for handling all headers.  Takes the interpolated header
# text, the line number, the indentation, and the surrounding marker for the
# alt formatting method.
sub heading {
    my ($self, $text, $level, $line) = @_;
    if ($$self{WAITING}) { $self->item }
    if ($$self{PENDING}) {
        $self->output ("]\n");
        $$self{PENDING} = 0;
    }
    $text =~ s/\s+$//;
    $text = $self->interpolate ($text, $line);
    $self->output ("\\h$level\[" . $text . "]\n\n");
}

##############################################################################
# List handling
##############################################################################

# This method is called whenever an =item command is complete (in other words,
# we've seen its associated paragraph or know for certain that it doesn't have
# one).  It gets the paragraph associated with the item as an argument.  At
# this point, we should have stored in $$self{ITEMS}[0] the command to open
# the item block.
sub item {
    my $self = shift;
    local $_ = shift;
    my $tag = $$self{ITEMS}[0];
    unless (defined $tag) {
        carp "Item called without tag";
        return;
    }
    if (!$tag) { $tag = '\\block' }
    if ($$self{WAITING}) {
        if ($$self{PENDING}) {
            $self->output ("]\n");
            $$self{PENDING} = 0;
        }
        $self->output ($tag . "\n[" . $_);
    } else {
        $self->output ($_);
    }
    $$self{PENDING} = 1;
    $$self{WAITING} = 0;
}

##############################################################################
# Output formatting
##############################################################################

# Wrap a line.  We can't use Text::Wrap because it plays games with tabs.  We
# can't use formline, even though we'd really like to, because it screws up
# non-printing characters.  So we have to do the wrapping ourselves.
sub reformat {
    my $self = shift;
    local $_ = shift;
    s/ +$//mg;
    s/\.\n/. \n/g;
    s/\n/ /g;
    s/   +/  /g;
    my $output = '';
    my $width = 74;
    while (length > $width) {
        if (s/^([^\n]{0,$width})\s+// || s/^([^\n]{$width})//) {
            $output .= $1 . "\n";
        } else {
            last;
        }
    }
    $output .= $_;
    $output =~ s/\s+$/\n\n/;
    $output;
}

# Output text to the output device.
sub output {
    my ($self, $text) = @_;
    if ($$self{SPACE}) {
        print { $self->output_handle } "]\n" if ($text =~ s/^\]\s*\n//);
        print $$self{SPACE};
        undef $$self{SPACE};
    }
    if ($text =~ s/\n(\n*)$/\n/) {
        $$self{SPACE} = $1;
    }
    print { $self->output_handle } $text;
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=head1 NAME

Pod::Thread - Convert POD data to the HTML macro language thread

=head1 SYNOPSIS

    use Pod::Thread;
    my $parser = Pod::Thread->new;

    # Read POD from STDIN and write to STDOUT.
    $parser->parse_from_filehandle;

    # Read POD from file.pod and write to file.th.
    $parser->parse_from_file ('file.pod', 'file.th');

=head1 DESCRIPTION

Pod::Thread is a module that can convert documentation in the POD format
(the preferred language for documenting Perl) into thread, an HTML macro
language.  It lets the converter from thread to HTML handle some of the
annoying parts of conversion to HTML.

As a derived class from Pod::Parser, Pod::Text supports the same methods and
interfaces.  See L<Pod::Parser> for all the details; briefly, one creates a
new parser with C<< Pod::Text->new() >> and then calls either
parse_from_filehandle() or parse_from_file().

new() can take options, in the form of key/value pairs that control the
behavior of the parser.  See below for details.

The standard Pod::Parser method parse_from_filehandle() takes up to two
arguments, the first being the file handle to read POD from and the second
being the file handle to write the formatted output to.  The first defaults
to STDIN if not given, and the second defaults to STDOUT.  The method
parse_from_file() is almost identical, except that its two arguments are the
input and output disk files instead.  See L<Pod::Parser> for the specific
details.

The recognized options to new() are as follows.  All options take a single
argument.

=over 4

=item style

Sets the name of the style sheet to use.  If not given, no reference to a
style sheet will be included in the generated page.

=back

=head1 DIAGNOSTICS

=over 4

=item Bizarre space in item

=item Item called without tag

(W) Something has gone wrong in internal C<=item> processing.  These
messages indicate a bug in Pod::Text; you should never see them.

=item Can't open %s for reading: %s

(F) Pod::Text was invoked via the compatibility mode pod2text() interface
and the input file it was given could not be opened.

=item %s:%d: Unknown command paragraph: %s

(W) The POD source contained a non-standard command paragraph (something of
the form C<=command args>) that Pod::Man didn't know about.  It was ignored.

=item %s:%d: Unknown escape: %s

(W) The POD source contained an C<EE<lt>E<gt>> escape that Pod::Text didn't
know about.

=item %s:%d: Unknown formatting code: %s

(W) The POD source contained a non-standard formatting code (something of
the form C<XE<lt>E<gt>>) that Pod::Text didn't know about.

=item %s:%d: Unmatched =back

(W) Pod::Text encountered a C<=back> command that didn't correspond to an
C<=over> command.

=back

=head1 SEE ALSO

L<Pod::Parser>, L<spin(1)>

=head1 AUTHOR

Russ Allbery <rra@stanford.edu>, based heavily on Pod::Text.

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Russ Allbery <rra@stanford.edu>.

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=cut
