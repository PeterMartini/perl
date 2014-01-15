package signatures;

use v5.019;

use strict;
use warnings;

our $VERSION = v0.08;

# Load the XS code
require XSLoader;
XSLoader::load('signatures', $VERSION);

sub import {
    $^H{signature_parser} = \&signatures::parser;
}

sub unimport {
    delete $^H{signature_parser};
}

1;

__END__

=head1 NAME

signatures - Provide named, formal parameters for subs (a.k.a. signatures)

=head1 VERSION

This document describes version 0.08

=head1 SYNOPSIS

    use signatures;
    sub foo($bar, @baz){...} # Equivalent to sub foo { my ($bar, @baz) = @_;...}

    OR

    use signatures;
    sub foo($@) { ... } # Prototypes can still be used

    OR

    use signatures;
    sub foo($bar, @baz) : prototype($@) {} # And the two can be combined

=head1 DESCRIPTION

When this module is loaded, subs can be declared with named, formal parameters
by declaring them in parentheses after the sub name.  The names must begin with
either C<$> for a scalar, C<@> for an array, or C<%> for a hash, and arrays and
hashes are limited to the final parameter in the list.  All of the standard
rules for lexical naming apply.
 
The effect of the declaration is to create new lexicals available for the life
of the sub and automatically initialized when the sub is called.

This can coexist with prototypes by using the prototype attribute, either at
declaration time (C<sub foo($$);> or C<sub foo : prototype($$);>) or at
definition time (C<sub foo($bar, $baz) : prototype($$) { }>).

=head1 NOTES

This module is the first version being bundled with Perl, and as such is
expected to be improved upon in later releases.

=head1 AUTHOR

Peter Martini E<lt>PeterCMartini@GMail.comE<gt>, inspired by the signatures module
written by Florian Ragwitz E<lt>rafl@debian.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2014  Peter Martini

This module is free software.

You may distribute it under the same license as Perl itself.

=cut
