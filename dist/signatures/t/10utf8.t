# Lightly modified from signatures 0.07 on CPAN

use strict;
use warnings;
use utf8;
use Test::More tests => 3;

use vars qw/@warnings/;
# BEGIN { $SIG{__WARN__} = sub { push @warnings, @_ } }

use signatures;

my $ret = eval "sub foo(\$c\x{327}){ \$c\x{327} } foo(100);"; # c + cedilla
is($@, '', "ASCII character + combining character works as a variable name");
is($ret, 100, "...and returns the correct value");

is(@warnings, 0, "This test should generate no warnings");
