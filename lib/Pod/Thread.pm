# Convert POD data to the HTML macro language thread.
#
# This module converts POD to the HTML macro language thread.  It's intended
# for use with the spin program to include POD documentation in a
# spin-generated web page complex.
#
# SPDX-License-Identifier: MIT

##############################################################################
# Modules and declarations
##############################################################################

package Pod::Thread;

use 5.010;
use strict;
use warnings;

use base qw(Pod::Simple);

use Carp qw(croak);
use Encode qw(encode);
use Text::Wrap qw(wrap);

our $VERSION = '0.0';

##############################################################################
# Internal constants
##############################################################################

# Include only the escapes that are basic ASCII or are not valid XHTML
# escapes.
my %ESCAPES = (
    amp    => q{&},    # ampersand
    apos   => q{'},    # apostrophe (')
    lt     => q{<},    # left chevron, less-than
    gt     => q{>},    # right chevron, greater-than
    quot   => q{"},    # double quote (")
    shy    => q{-},    # soft (discretionary) hyphen
    sol    => q{/},    # solidus (forward slash)
    verbar => q{|},    # vertical bar
);

# Regex matching a manpage-style entry in the NAME header.  $1 is set to the
# list of things documented by the man page, and $2 is set to the description.
my $NAME_REGEX = qr{ \A ( \S+ (?:,\s*\S+)* ) [ ] - [ ] (.*) }xms;

# Maximum length of each line when constructing a navbar.
my $NAVBAR_LENGTH = 65;

# Margin at which to wrap thread output.
my $WRAP_MARGIN = 75;

##############################################################################
# Initialization
##############################################################################

# Called for every non-POD line in the file.  This is used to grab the Id
# string (from a CVS or Subversion tag) if present in the file.  If we see
# this before the start of the POD, we use it to generate a thread \id
# command.
#
# $line   - The non-POD line
# $number - The line number of the input file
# $parser - The Pod::Thread parser
#
# Returns: undef
sub handle_code {
    my ($line, $line_number, $self) = @_;
    if (!$self->{opt_id} && $line =~ m{ (\$ Id: .* \$) }xms) {
        $self->{opt_id} = $1;
    }
    return;
}

# Initialize the object and set various Pod::Simple options that we need.
# Here, we also process any additional options passed to the constructor or
# set up defaults if none were given.  Note that all internal object keys are
# in all-caps, reserving all lower-case object keys for Pod::Simple and user
# arguments.  User options are rewritten to start with opt_ to avoid conflicts
# with Pod::Simple.
#
# $class - Our class as passed to the constructor
# %opts  - Our options as key/value pairs
#
# Returns: Newly constructed Pod::Thread object
#  Throws: Whatever Pod::Simple's constructor might throw
sub new {
    my ($class, %opts) = @_;
    my $self = $class->SUPER::new;

    # Tell Pod::Simple to handle S<> by automatically inserting E<nbsp>.
    $self->nbsp_for_S(1);

    # The =for and =begin targets that we accept.
    $self->accept_targets('thread');

    # Ensure that contiguous blocks of code are merged together.
    $self->merge_text(1);

    # Preserve whitespace whenever possible to make debugging easier.
    $self->preserve_whitespace(1);

    # Pod::Simple doesn't do anything useful with our arguments, but we want
    # to put them in our object as hash keys and values.  This could cause
    # problems if we ever clash with Pod::Simple's own internal class
    # variables, so rename them with an opt_ prefix.
    my @opts = map { ("opt_$_", $opts{$_}) } keys %opts;
    %{$self} = (%{$self}, @opts);

    # Always send errors to standard error.
    $self->no_errata_section(1);
    $self->complain_stderr(1);

    # Look for Id strings in non-POD lines.
    $self->code_handler(\&handle_code);

    return $self;
}

##############################################################################
# Core parsing
##############################################################################

# This is the glue that connects the code below with Pod::Simple itself.  The
# goal is to convert the event stream coming from the POD parser into method
# calls to handlers once the complete content of a tag has been seen.  Each
# paragraph or POD command will have textual content associated with it, and
# as soon as all of a paragraph or POD command has been seen, that content
# will be passed in to the corresponding method for handling that type of
# object.  The exceptions are handlers for lists, which have opening tag
# handlers and closing tag handlers that will be called right away.
#
# The internal hash key PENDING is used to store the contents of a tag until
# all of it has been seen.  It holds a stack of open tags, each one
# represented by a tuple of the attributes hash for the tag and the contents
# of the tag.

# Pod::Simple uses subroutines named as if they're private for subclassing.
## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)

# Add a block of text to the contents of the current node, protecting any
# thread metacharacters as we do.
#
# $self - Pod::Thread object
# $text - A block of ordinary text seen in the POD
#
# Returns: undef
sub _handle_text {
    my ($self, $text) = @_;
    $text =~ s{ \\ }{\\\\}xmsg;
    $text =~ s{ ([\[\]]) }{'\\entity[' . ord($1) . ']'}xmseg;
    my $tag = $self->{PENDING}[-1];
    $tag->[1] .= $text;
    return;
}

# Given an element name, get the corresponding portion of a method name.  The
# real methods will be formed by prepending cmd_, start_, or end_.
#
# $self    - Pod::Thread object.
# $element - Name of the POD element by Pod::Simple's naming scheme.
#
# Returns: The element transformed into part of a method name.
sub method_for_element {
    my ($self, $element) = @_;
    $element =~ tr{-}{_};
    $element =~ tr{A-Z}{a-z};
    $element =~ tr{_a-z0-9}{}cd;
    return $element;
}

# Handle the start of a new element.  If cmd_element is defined, assume that
# we need to collect the entire tree for this element before passing it to the
# element method, and create a new tree into which we'll collect blocks of
# text and nested elements.  Otherwise, if start_element is defined, call it.
#
# $self    - Pod::Thread object
# $element - The name of the POD element that was started
# $attrs   - The attribute hash for that POD element.
#
# Returns: undef
sub _handle_element_start {
    my ($self, $element, $attrs) = @_;
    my $method = $self->method_for_element($element);

    # If we have a command handler, we need to accumulate the contents of the
    # tag before calling it.  If we have a start handler, call it immediately.
    if ($self->can("cmd_$method")) {
        push(@{ $self->{PENDING} }, [$attrs, q{}]);
    } elsif ($self->can("start_$method")) {
        $method = 'start_' . $method;
        $self->$method($attrs, q{});
    }
    return;
}

# Handle the end of an element.  If we had a cmd_ method for this element,
# this is where we pass along the text that we've accumulated.  Otherwise, if
# we have an end_ method for the element, call that.
sub _handle_element_end {
    my ($self, $element) = @_;
    my $method = $self->method_for_element($element);

    # If we have a command handler, pull off the pending text and pass it to
    # the handler along with the saved attribute hash.  Otherwise, if we have
    # an end method, call it.
    if ($self->can("cmd_$method")) {
        my $tag = pop @{ $self->{PENDING} };
        $method = 'cmd_' . $method;
        my $text = $self->$method(@{$tag});

        # If the command returned some text, check if the element stack is
        # non-empty.  If so, add that text to the next open element.
        # Otherwise, we're at the top level and can output the text directly.
        if (defined $text) {
            if (@{ $self->{PENDING} } > 1) {
                $self->{PENDING}[-1][1] .= $text;
            } else {
                $self->output($text);
            }
        }
        return;
    } elsif ($self->can("end_$method")) {
        $method = 'end_' . $method;
        return $self->$method;
    } else {
        return;
    }
}

# Private subroutines from here on out actually are.
## use critic

##############################################################################
# Output formatting
##############################################################################

# Wrap a line at 74 columns.  Strictly speaking, there's no reason to do this
# for thread output since thread is not sensitive to long lines, but it makes
# the output more readable.
#
# $self - Pod::Thread object
# $text - Text to wrap
#
# Returns: Wrapped text
sub reformat {
    my ($self, $text) = @_;

    # Strip trailing whitespace.
    $text =~ s{ [ ]+ \z }{}xmsg;

    # Collapse newlines to spaces while ensuring there are two spaces after
    # periods.  (HTML won't care, but I do.)
    $text =~ s{ [.]\n }{. \n}xmsg;
    $text =~ s{ \n }{ }xmsg;
    $text =~ s{ [ ]{3,} }{  }xmsg;

    # Delegate the wrapping to Text::Wrap.
    local $Text::Wrap::columns  = $WRAP_MARGIN;
    local $Text::Wrap::huge     = 'overflow';
    local $Text::Wrap::unexpand = 0;
    my $output = wrap(q{}, q{}, $text);

    # Remove stray leading spaces at the start of lines, created by Text::Wrap
    # getting confused by two spaces after a period.
    $output =~ s{ \n [ ] (\S) }{\n$1}xmsg;

    # Ensure the result ends in two newlines.
    $output =~ s{ \s* \z }{\n\n}xms;
    return $output;
}

# Output text to the output device.  Force the encoding to UTF-8 unless we've
# found that we already have a UTF-8 encoding layer.  We may have some
# accumulated whitespace in the SPACE internal variable; if so, add that after
# any closing bracket at the start of our output.  Then, save any whitespace
# at the end of our output and defer it for next time.  (This creates much
# nicer association of closing brackets.)
#
# $self - Pod::Thread object
# $text - Text to output
#
# Returns: undef
sub output {
    my ($self, $text) = @_;

    # If we have deferred whitespace, output it before the text, but after any
    # closing bracket at the start of the text.
    if ($self->{SPACE}) {
        if ($text =~ s{ \A \] \s* \n }{}xms) {
            print { $self->{output_fh} } "]\n"
              or die "Cannot write to output: $!\n";
        }
        print { $self->{output_fh} } $self->{SPACE}
          or die "Cannot write to output: $!\n";
        undef $self->{SPACE};
    }

    # Defer any trailing newlines beyond a single newline.
    if ($text =~ s{ \n (\n+) \z }{\n}xms) {
        $self->{SPACE} = $1;
    }

    # Encode the output as needed.
    if ($self->{ENCODE}) {
        $text = encode('UTF-8', $text);
    }

    # Output the text.
    print { $self->{output_fh} } $text
      or die "Cannot write to output: $!\n";
    return;
}

##############################################################################
# Document start and finish
##############################################################################

# From a hash of section names to tags, produce a sorted list of sections.
# The tag must be numeric from the second character on, and the sections will
# be sorted by the numeric tag.
#
# $self     - The Pod::Thread object
# $sections - A hash of formatted section headings to tags
#
# Returns: A list formatted section headings
sub sorted_sections {
    my ($self, $sections) = @_;
    my $by_tag = sub {
        my ($one, $two) = @_;
        my $an = substr($sections->{$one}, 1);
        my $bn = substr($sections->{$two}, 1);
        return $an <=> $bn;
    };
    my @sorted = sort { $by_tag->($a, $b) } keys %{$sections};
    return @sorted;
}

# Output a table of contents at the beginning of a document if the contents
# option is set.  If it is, it will be a map from the formatted contents of
# headings to a tag to use for that heading.  The table of contents will be
# presented in the sorted order of the tags.
#
# $self - The Pod::Thread object
#
# Returns: undef
sub output_contents {
    my ($self) = @_;
    if (!$self->{opt_contents}) {
        return;
    }

    # Transform the sections into a sorted list of formatted headings.
    my @sections = $self->sorted_sections($self->{opt_contents});

    # Output the table of contents.
    $self->output("\\h2[Table of Contents]\n\n");
    for my $section (@sections) {
        my $tag = $self->{opt_contents}{$section};
        $self->output("\\number(packed)[\\link[#$tag][$section]]\n");
    }
    $self->output("\n");
    return;
}

# Output a navigation bar at the beginning of a document.  This is like a
# table of contents, but lists the sections separated by vertical bars and
# tries to limit the number of sections per line.  This is only done if the
# navbar option is set.  If it is, it will be a map from the formatted
# contents of headings to a tag to use for that heading, just like the
# contents option.  The navbar will be presented in the sorted order of the
# tags.
#
# $self - The Pod::Thread object
#
# Returns: undef
sub output_navbar {
    my ($self) = @_;
    if (!$self->{opt_navbar}) {
        return;
    }

    # Transform the sections into a sorted list of formatted headings.
    my @sections = $self->sorted_sections($self->{opt_navbar});

    # Output the start of the navbar.
    $self->output("\\class(navbar)[\n  ");

    # Format the navigation bar, accumulating each line in $output.  Store the
    # formatted length in $length.  We can't use length($output) because that
    # would count all the thread commands.  This won't be quite right if
    # headings contain formatting.
    my $output = q{};
    my $length = 0;
    for my $section (@sections) {
        my $tag = $self->{opt_navbar}{$section};

        # If adding this section would put us over 60 characters, output the
        # current line with a line break.
        if ($length + length($section) > $NAVBAR_LENGTH) {
            $self->output("$output\\break\n  ");
            $output = q{};
            $length = 0;
        }

        # If this isn't the first thing on a line, add the separator.
        if (length($output) != 0) {
            $output .= q{  | };
            $length += length(q{ | });
        }

        # Convert the section names to titlecase.
        my $name = join(q{ }, map { ucfirst(lc) } split(q{ }, $section));
        $name =~ s{ \b And \b }{and}xmsg;

        # Add it to the current line.
        $output .= "\\link[#$tag][$name]\n";
        $length += length($name);
    }

    # Output any remaining partial line and the end of the navbar.
    if (length($output) > 0) {
        $self->output($output);
    }
    $self->output("]\n\n");
    return;
}

# Print out the header and title of the document, including any navigation bar
# and contents section if we have any.
#
# $self       - Pod::Thread object
# $title      - Document title
# $subheading - Document subheading (may be undef)
#
# Returns: undef
sub output_header {
    my ($self, $title, $subheading) = @_;
    my $style = $self->{opt_style} || q{};
    if ($self->{opt_id}) {
        $self->output("\\id[$self->{opt_id}]\n\n");
    }
    $self->output("\\heading[$title][$style]\n\n");
    $self->output("\\h1[$title]\n\n");
    if (defined $subheading) {
        $self->output("\\class(subhead)[($subheading)]\n\n");
    }
    $self->output_navbar;
    $self->output_contents;
    return;
}

# Handle the beginning of a POD file.  We only output something if title is
# set, in which case we output the title and other header information at the
# beginning of the resulting output file.
#
# $self  - Pod::Thread object
# $attrs - Attributes of the start document tag
#
# Returns: undef
sub start_document {
    my ($self, $attrs) = @_;

    # If the document has no content, set the appropriate internal flag.
    if ($attrs->{contentless}) {
        $self->{CONTENTLESS} = 1;
    } else {
        delete $self->{CONTENTLESS};
    }

    # Initialize per-document variables.
    $self->{IN_NAME}      = 0;
    $self->{ITEM_OPEN}    = 0;
    $self->{ITEM_PENDING} = 0;
    $self->{ITEMS}        = [];
    $self->{PENDING}      = [[]];

    # Check whether our output file handle already has a PerlIO encoding layer
    # set.  If it does not, we'll need to encode our output before printing it
    # (handled in the output method).  Wrap the check in an eval to handle
    # versions of Perl without PerlIO.
    $self->{ENCODE} = 1;
    eval {
        my @options = (output => 1, details => 1);
        my $flag    = (PerlIO::get_layers($self->{output_fh}, @options))[-1];
        if (defined($flag) && ($flag & PerlIO::F_UTF8())) {
            $self->{ENCODE} = 0;
        }
    };

    # If there was a title option, handle it now.
    if ($self->{opt_title}) {
        $self->output_header($self->{opt_title});
    }
    return;
}

# Handle the end of the document.  Tack \signature onto the end, and then die
# if we saw any errors.
#
# $self - Pod::Thread object
#
# Returns: undef
sub end_document {
    my ($self) = @_;
    $self->output("\\signature\n");
    if ($self->errors_seen) {
        croak('POD document had syntax errors');
    }
    return;
}

##############################################################################
# Text blocks
##############################################################################

# Called for each paragraph of text that we see inside an item.  It's also
# called with no text when it's time to close an item even though there wasn't
# any text associated with it (which happens for description lists).  The top
# of the ITEMS stack will hold the command that should be used to open the
# item block in thread.
#
# $self - Pod::Thread object
# $text - Contents of the text block inside =item
#
# Returns: undef
sub item {
    my ($self, $text) = @_;

    # If there wasn't anything waiting, we're in the second or subsequent
    # paragraph of the item text.  Just output it.
    if (!$self->{ITEM_PENDING}) {
        $self->output($text);
        return;
    }

    # We're starting a new item.  Close any pending =item block.
    if ($self->{ITEM_OPEN}) {
        $self->output("]\n");
        $self->{ITEM_OPEN} = 0;
    }

    # Now, output the start of the item tag plus the text, if any.
    my $tag = $self->{ITEMS}[-1];
    $text = defined($text) ? $text : q{};
    $self->output($tag . "\n[" . $text);
    $self->{ITEM_OPEN}    = 1;
    $self->{ITEM_PENDING} = 0;
    return;
}

# Called for a regular text block.  There are two tricky parts here.  One is
# that if there is a pending item tag, we need to format this as an item
# paragraph.  The second is that if we're in the NAME section and see the name
# and description of the page, we should print out the header.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: undef
sub cmd_para {
    my ($self, $attrs, $text) = @_;

    # Ensure the text block ends with a single newline.
    $text =~ s{ \s+ \z }{\n}xms;

    # If we're inside an item block, handle this as an item.
    if (@{ $self->{ITEMS} } > 0) {
        $self->item($self->reformat($text));
    }

    # If we're in the NAME section and see a line that looks like the special
    # NAME section of a man page, that's our cue to print out the page
    # heading.
    elsif ($self->{IN_NAME} && $text =~ $NAME_REGEX) {
        my ($name, $description) = ($1, $2);
        $self->output_header($name, $description);
    }

    # Otherwise, this is a regular text block, so just output it with a
    # trailing blank line.
    else {
        $self->output($self->reformat($text . "\n"));
    }
    return;
}

# Called for a verbatim paragraph.  The only trick is knowing whether to use
# the item method to handle it or just print it out directly.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: undef
sub cmd_verbatim {
    my ($self, $attrs, $text) = @_;

    # Ignore empty verbatim paragraphs.
    if ($text =~ m{ \A \s* \z }xms) {
        return;
    }

    # Ensure the paragraph ends in a bracket and two newlines.
    $text =~ s{ \s* \z }{\]\n\n}xms;

    # Pass the text to either item or output.
    if (@{ $self->{ITEMS} } > 0) {
        $self->item("\\pre\n[$text");
    } else {
        $self->output("\\pre\n[$text");
    }
    return;
}

# Called for literal text produced by =for and similar constructs.  Just
# output the text verbatim.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: undef
sub cmd_data {
    my ($self, $attrs, $text) = @_;
    $self->output($text);
    return;
}

##############################################################################
# Headings
##############################################################################

# The common code for handling all headings.  Take care of any pending items
# or lists and then output the thread code for the heading.
#
# $self  - Pod::Thread object
# $text  - The text of the heading itself
# $level - The level of the heading as a number (2..5)
# $tag   - An optional tag for the heading
#
# Returns: undef
sub heading {
    my ($self, $text, $level, $tag) = @_;

    # If there is a waiting item or a pending close bracket, output it now.
    $self->finish_item;

    # Strip any trailing whitespace.
    $text =~ s{ \s+ \z }{}xms;

    # Output the heading thread.
    if (defined $tag) {
        $self->output("\\h$level($tag)[$text]\n\n");
    } else {
        $self->output("\\h$level" . "[$text]\n\n");
    }
    return;
}

# First level heading.  This requires some special handling to update the
# IN_NAME setting based on whether we're currently in the NAME section.  Also
# add a tag to the heading if we have section information.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: The result of the heading method
sub cmd_head1 {
    my ($self, $attrs, $text) = @_;

    # Strip whitespace from the text since we're going to compare it to other
    # things.
    $text =~ s{ \s+ \z }{}xms;

    # If we're in the NAME section and no title was explicitly set, set the
    # flag used in cmd_para to parse the NAME text specially and then do
    # nothing else (since we won't print out the NAME section as itself.
    if ($text eq 'NAME' && !exists($self->{opt_title})) {
        $self->{IN_NAME} = 1;
        return;
    }

    # Not in the name section.  See if we have section information, and if so,
    # add a tag to the header.  We have to strip any embedded markup from the
    # section text.
    $self->{IN_NAME} = 0;
    my $sections = $self->{opt_contents} || $self->{opt_navbar};
    my $section  = $text;
    $section =~ s{ \\ \w+ \[ ([^\]]+) \] }{$1}xmsg;
    if ($sections && $sections->{$section}) {
        return $self->heading($text, 2, "#$sections->{$section}");
    } else {
        return $self->heading($text, 2);
    }
}

# All the other headings, which just hand off to the heading method.
sub cmd_head2 { my ($self, $atr, $text) = @_; return $self->heading($text, 3) }
sub cmd_head3 { my ($self, $atr, $text) = @_; return $self->heading($text, 4) }
sub cmd_head4 { my ($self, $atr, $text) = @_; return $self->heading($text, 5) }

##############################################################################
# List handling
##############################################################################

# Output any waiting items and close any pending blocks.
#
# $self - Pod::Thread object
#
# Returns: undef
sub finish_item {
    my ($self) = @_;
    if ($self->{ITEM_PENDING}) {
        $self->item;
    }
    if ($self->{ITEM_OPEN}) {
        $self->output("]\n");
        $self->{ITEM_OPEN} = 0;
    }
    return;
}

# Handle the beginning of an =over block.  This is called by the handlers for
# the four different types of lists (bullet, number, desc, and block).  Update
# our internal tracking for =over blocks.
#
# $self - Pod::Thread object
# $type - Type of =over block
#
# Returns: undef
sub over_common_start {
    my ($self, $type, $attrs) = @_;
    $self->{ITEM_OPEN} = 0;
    push(@{ $self->{ITEMS} }, q{});
    return;
}

# Handle the end of a list.  Output any waiting items, close any pending
# blocks, and pop one level of item off the item stack.
#
# $self  - Pod::Thread object
#
# Returns: undef
sub over_common_end {
    my ($self) = @_;

    # If there is a waiting item or a pending close bracket, output it now.
    $self->finish_item;

    # Pop the item off the stack.
    pop(@{ $self->{ITEMS} });

    # Set pending based on whether there's still another level of item open.
    if (@{ $self->{ITEMS} } > 0) {
        $self->{ITEM_OPEN} = 1;
    }
    return;
}

# All the individual start commands for the specific types of lists.  These
# are all dispatched to the relevant common routine.
sub start_over_block  { my ($s) = @_; return $s->over_common_start('block') }
sub start_over_bullet { my ($s) = @_; return $s->over_common_start('bullet') }
sub start_over_number { my ($s) = @_; return $s->over_common_start('number') }
sub start_over_text   { my ($s) = @_; return $s->over_common_start('desc') }

# Likewise for the end commands.
sub end_over_block  { my ($self) = @_; return $self->over_common_end() }
sub end_over_bullet { my ($self) = @_; return $self->over_common_end() }
sub end_over_number { my ($self) = @_; return $self->over_common_end() }
sub end_over_text   { my ($self) = @_; return $self->over_common_end() }

# An individual list item command.  Note that this fires when the =item
# command is seen, not when we've accumulated all the text that's part of that
# item.  We may have some body text and we may not, but we have to defer the
# end of the item until the surrounding =over is closed.
#
# The type of the item is ignored, since we already determined that in the
# =over block and saved it.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: undef
sub item_common {
    my ($self, $type, $attrs, $text) = @_;

    # If we saw an =item command, any previous item block is finished, so
    # output that now.
    if ($self->{ITEM_PENDING}) {
        $self->item();
    }

    # The top of the stack should now contain our new type of item.
    $self->{ITEMS}[-1] = "\\$type";

    # We now have an item waiting for output.
    $self->{ITEM_PENDING} = 1;

    # If the type is desc, anything in $text is the description title and
    # needs to be appended to our ITEM.
    if ($self->{ITEMS}[-1] eq '\\desc') {
        $text =~ s{ \s+ \z }{}xms;
        $self->{ITEMS}[-1] .= "[$text]";
    }

    # Otherwise, anything in $text is body text.  Handle that now.
    else {
        $self->item($self->reformat($text));
    }

    return;
}

# All the various item commands just call item_common.
## no critic (Subroutines::RequireArgUnpacking)
sub cmd_item_block  { my $s = shift; return $s->item_common('block',  @_) }
sub cmd_item_bullet { my $s = shift; return $s->item_common('bullet', @_) }
sub cmd_item_number { my $s = shift; return $s->item_common('number', @_) }
sub cmd_item_text   { my $s = shift; return $s->item_common('desc',   @_) }
## use critic

##############################################################################
# Formatting codes
##############################################################################

# The simple ones.  These are here mostly so that subclasses can override them
# and do more complicated things.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: The formatted text
sub cmd_b { my ($self, $attrs, $text) = @_; return "\\bold[$text]" }
sub cmd_c { my ($self, $attrs, $text) = @_; return "\\code[$text]" }
sub cmd_f { my ($self, $attrs, $text) = @_; return "\\italic(file)[$text]" }
sub cmd_i { my ($self, $attrs, $text) = @_; return "\\italic[$text]" }
sub cmd_x { return q{} }

# Format a link.  Don't try to actually generate hyperlinks for anything other
# than normal URLs and section links within our same document.  For the
# latter, we can only do this if we have section information from our
# configuration.
#
# $self  - Pod::Thread object
# $attrs - Attributes for this command
# $text  - The text of the block
#
# Returns: The formatted link
sub cmd_l {
    my ($self, $attrs, $text) = @_;
    if ($attrs->{type} eq 'url') {
        if (!defined($attrs->{to}) || $attrs->{to} eq $text) {
            return "<\\link[$text][$text]>";
        } else {
            return "\\link[$attrs->{to}][$text]";
        }
    } elsif ($attrs->{type} eq 'pod') {
        my $page     = $attrs->{to};
        my $section  = $attrs->{section};
        my $sections = $self->{opt_contents} || $self->{opt_navbar};
        if (!defined($page) && defined($section) && $sections->{$section}) {
            $text =~ s{ \A \" }{}xms;
            $text =~ s{ \" \z }{}xms;
            return "\\link[#$sections->{$section}][$text]";
        }
    }

    # Fallthrough just returns the preformatted text from Pod::Simple.
    return defined($text) ? $text : q{};
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

=for stopwords
Allbery CVS STDIN STDOUT navbar podlators MERCHANTABILITY NONINFRINGEMENT
sublicense

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

As a derived class from Pod::Parser, Pod::Thread supports the same methods
and interfaces.  See L<Pod::Parser> for all the details; briefly, one
creates a new parser with C<< Pod::Thread->new() >> and then calls either
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

=item contents

Asks for a table of contents section at the beginning of the document.
Should be set to a hash table mapping section headers to section numbers
prefixed by S (for internal links).

=item id

Sets the CVS Id string for the file.  If this isn't set, Pod::Thread will
try to find it in the file, but will only successfully find it if it occurs
before the beginning of any POD in the input file.

=item navbar

Asks for a navigation bar at the beginning of the document.  Should be set
to a hash table mapping section headers to section numbers prefixed by S
(for internal links).

=item style

Sets the name of the style sheet to use.  If not given, no reference to a
style sheet will be included in the generated page.

=item title

The title of the document.  If this is set, it will be used rather than
looking for and parsing a NAME section in the POD file, and NAME sections
will no longer be required or special.

=back

=head1 DIAGNOSTICS

=over 4

=item Cannot write to output: %s

(F) An error occurred while attempting to write the thread result to the
configured output string or file handle.

=item POD document had syntax errors

(F) The POD document being formatted had syntax errors.

=back

=head1 SEE ALSO

L<Pod::Parser>, L<spin(1)>

Current versions of this program are available from my web tools page at
L<http://www.eyrie.org/~eagle/software/web/>.  B<spin> is available from the
same page.

=head1 AUTHOR

Russ Allbery <rra@cpan.org>, based heavily on Pod::Text from podlators.

=head1 COPYRIGHT AND LICENSE

Copyright 2002, 2008-2009, 2013, 2021 Russ Allbery <rra@cpan.org>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut

# Local Variables:
# copyright-at-end-flag: t
# End:
