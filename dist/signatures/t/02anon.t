# Lightly modified from signatures 0.07 on CPAN

use strict;
use warnings;
use Test::More tests => 1;

use signatures;

my $foo = sub ($bar, $baz) { return "${bar}-${baz}" };

is($foo->(qw/bar baz/), 'bar-baz');
