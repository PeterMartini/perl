#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = qw(. ../lib);
}

use strict;
use warnings;

BEGIN {
    require 'test.pl';
    plan( tests => 54 );
}

our @warnings;
BEGIN { $SIG{__WARN__} = sub { push @warnings, @_ } }

# Basic tests with feature enabled 
{
    use feature 'signatures';

    sub foo ($bar) { $bar }
    sub array ($scalar, @array) { return $scalar + @array; }
    sub hash (%hash) { return keys %hash; }
    sub Name::Space ($moo) { $moo }
    sub nosig27 { }

    BEGIN {
        like(shift @warnings, qr/signatures feature is experimental/, "Emit experimental features warning once");
        like(shift @warnings, qr/signatures feature is experimental/, " ... twice");
        like(shift @warnings, qr/signatures feature is experimental/, " ... thrice");
        like(shift @warnings, qr/signatures feature is experimental/, " ... and done");
        is(@warnings, 0, "But no others are");
    }

    is(foo('baz'), 'baz', "Single scalar signature works");
    is(array(10, 1..10), 20, "Single array signature works");
    is(1, eq_array([sort(hash(foo => 1, bar => 2))],[sort(qw/foo bar/)]), "Single hash signature works");
    is(Name::Space("Test"), "Test", "Namespaces are fine");

    is(@warnings, 0, "No runtime warnings");
}

no warnings 'experimental::signatures';

# Confirm no warnings works
{
    use feature 'signatures';
    sub foo50 ($bar) { $bar }

    BEGIN {
        is(@warnings, 0, "No warnings worked");
    }
}

# Scoping
sub nosig($bar) { }
BEGIN {
    like(shift @warnings, qr/Illegal character in prototype/, "Feature is lexically scoped");
    is(@warnings, 0, "And no other warnings");
}

# Anonymous subs
{
    use feature 'signatures';

    my $foo = sub ($bar, $baz) { return "${bar}-${baz}"; };
    is($foo->(qw/bar baz/), 'bar-baz', "Sub references are fine");
    BEGIN {
        is(@warnings, 0, "No warnings for anonymous subs at compiletime");
    }
    is(@warnings, 0, "No warnings for anonymous subs at runtime");
diag @warnings;
}

# Test in eval
{
    use feature 'signatures';

    eval 'sub foo63 ($bar) { $bar }';
    ok(!$@, "signatures parse in eval");
    diag $@ if $@;
    ok(\&foo63, "sub declared in eval is present");
    is(foo63(42), 42, "evaled sub works");
    is(@warnings, 0, "No warnings for evaled subs");
}

# Test that eval doesn't have signatures in scope unless its meant to
{
    eval 'sub foo73 ($bar) { $bar }';
    like($@, qr/requires explicit package name/, "evaled sub without signatures in scope is fine");
    like(shift @warnings, qr/Illegal character in prototype/, "Feature is lexically scoped");
    is(@warnings, 0, "And no other warnings");
}

# Conjunction with prototype attribute
{
    use feature 'signatures';

    sub foo83 ($a, $b, $c) : prototype($$$) { return $a + $b + $c; }

    BEGIN {
        is(@warnings, 0, "No warnings mixing signatures and prototypes");
    }

    is(prototype(\&foo83), '$$$', "prototype registered on the sub");
    eval "foo83(1,2);";
    like($@, qr/Not enough arguments/, "prototype enforced on the sub");
    is(eval "foo83(1,2,3)", 6, "and the sub still works");
}

# No falling back
{
    use feature 'signatures';

    eval 'sub legalproto($$) {}';
    like $@, qr/Can't use global/, "No fallback for \$\$ and \$\$ itself is illegal";

    is eval 'sub ambiguous() {}; 1 if ! defined prototype \&ambiguous;', 1, "No prototype in the ambiguous case either";
}

# Some parsing stress tests
{
    use feature 'signatures';

    sub foo119 # Has a comment after the sub name
        ($bar) # And a comment after the signature
        : prototype($) # Even a comment after the prototype attribute
    {
       $bar;
    }

    BEGIN {
        is(@warnings, 0, "No warnings");
    }
    is(prototype(\&foo119), '$', "And the prototype attribute applied");
    is(foo119("baz"), "baz", "And the signature applied");
}

# Confirm lexicals are always fresh
{
    use feature 'signatures';

    sub foo137($a, @b) { "$a @b"; }

    is(foo137(1,2,3), "1 2 3", "Standard call is fine");
    is(foo137(4,5), "4 5", "Array with one element is fine");
    is(foo137(4), "4 ", "Array with no elements is fine");
    is(@warnings, 0, "No warnings here");
}

# Test parameter count mismatch
{
    use feature 'signatures';

    sub foo165($first, $second) { }

    eval { foo165(1,2,3); };
    like($@, qr/Too many arguments/, "Too many arguments croaks");

    eval { foo165(1); };
    like($@, qr/Not enough arguments/, "Too few arguments croaks");
}

# Only allow legal lexical variables - no barewords or qualifiers
{
    use feature 'signatures';

    eval 'sub foo151($1) {}';
    like($@, qr/Can't use global \$1/, "Regex match vars are illegal");

    eval 'sub foo154($bar::baz) {}';
    like($@, qr/can't be in a package/, "Package variables are illegal");

    eval 'sub foo157($bar, undef, $baz) { "$bar $baz"}';
    is($@, "", "undef is legal and means skip this param");
    is(eval 'foo157 1,2,3', "1 3", "... returns successfull");
    eval 'foo157 1, 2';
    like($@, qr/Not enough/, "... and enforces arity");

    eval 'sub foo160($bar, sin) {}';
    like($@, qr/Unexpected sin/, "Other operators not allowed either");

    eval 'sub foo163(*bar) {}';
    like($@, qr/syntax error/, "A glob is a syntax error");

    eval 'sub foo166($bar, ^baz) {}';
    like($@, qr/syntax error/, "Anything else is a syntax error");

    eval 'sub foo169(local our $bar) {}';
    like($@, qr/syntax error/, "local our is not allowed");
}

# Croak on duplicate names
{
    use feature 'signatures';

    eval 'sub foo174($bar, $bar){}';
    like($@, qr/Duplicate name in signature for /, "Duplicate names are fatal");
    {
        like(shift @warnings, qr/masks earlier declaration/, "Duplicate names also warn");
        is(@warnings, 0, " ... and no other warnings");
    }

    eval 'sub foo177($bar, @bar){}';
    is($@,'',"\$bar and \@bar is a terrible idea, but not actually a duplicate");
}

# Greedy things must be last
{
    use feature 'signatures';

    eval 'sub foo190(@bar, $baz){}';
    like($@, qr/Illegal parameter/, "arrays must come at the end");

    eval 'sub foo190(%bar, $baz){}';
    like($@, qr/Illegal parameter/, "hashes must come at the end");
}

# Lexical subs test
{
    use feature 'signatures';
    use feature 'lexical_subs';
    no warnings 'experimental::lexical_subs';

    my sub foo($bar) { "my foo $bar" };
    is(foo(1), "my foo 1", "Lexical subs process");
}
