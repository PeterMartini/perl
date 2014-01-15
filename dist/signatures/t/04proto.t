# Lightly modified from signatures 0.07 on CPAN

use strict;
use warnings;
use Test::More tests => 11;

use vars qw/@warnings/;
BEGIN { $SIG{__WARN__} = sub { push @warnings, @_ } }

BEGIN { is(@warnings, 0, 'no warnings yet') }

use signatures;

# prototype attribute by itself
sub with_proto ($x, $y, $z) : prototype($$$) { return $x + $y + $z; }
is(prototype('with_proto'), '$$$', ':prototype attribute');
BEGIN { is(@warnings, 0, 'no warnings with correct :prototype declarations') }

# prototype attribute and lvalue
{
    my $foo;
    sub with_lvalue ($bar) : lvalue prototype() { $foo }
}
is(prototype('with_lvalue'), '', ':prototype with other attributes');
BEGIN { is(@warnings, 0, 'no warnings with correct :prototype declarations + lvalue') }
with_lvalue = 1;
is(with_lvalue, 1, 'other attributes still there');

# Invalid
sub invalid_proto ($x) : prototype(invalid) { $x }
BEGIN {
    is(@warnings, 1, 'warning with illegal :prototype');
    like(shift @warnings, qr/Illegal character in prototype/, 'warning looks sane');
}

# Even with use signatures in effect, falls back to prototypes if no alpha
sub fallback(\@) { my $x; ref shift }
is(prototype('fallback'), '\@', 'A valid prototype is still valid');
is(fallback(my @arr), 'ARRAY', 'Confirm prototype magic takes effect');

# And the ambiguous case of empty (or all whitespace) string is considered a prototype
sub whitespace(     ) { my $x; }
like(prototype('whitespace'), qr/^\s*$/, 'whitespace has a no arg prototype');
