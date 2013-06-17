use Test::More tests => 18;
use XS::APItest;

sub bar {}
is test_cv_get_signature_pv(\&bar), undef, "undef by default";
test_cv_set_signature_pv(\&bar, "test sig");
is test_cv_get_signature_pv(\&bar), "test sig", "test sig set successfully";
test_cv_set_signature_pv(\&bar, "test sig2");
is test_cv_get_signature_pv(\&bar), "test sig2", "test sig2 set successfully";
test_cv_set_signature_pv(\&bar, undef);
is test_cv_get_signature_pv(\&bar), undef, "unset successfully";

# Test a closure where our ck helper applies the signature to the prototype
{
  sub closure1 {
    BEGIN{ $^H{"proto_sig"} = "test"; }
    my $a = shift;
    return sub { $a + shift }
  }
	my $sub1 = closure1();
  is test_cv_get_signature_pv($sub1), "test", "Signature cloned on anonymous CV";
	test_cv_set_signature_pv($sub1, undef);
	is test_cv_get_signature_pv($sub1), undef, "Closure signature is clearable";
	is test_cv_get_signature_pv(closure1()), "test", "Signature cloned on anonymous CV still \"test\"";
}

# Test a closure where the prototype has nothing set
{
  sub closure2 {
    my $a = shift;
    return sub { $a + shift }
  }
	my $sub1 = closure2();
  is test_cv_get_signature_pv($sub1), undef, "No signature on the closure when it wasn't set";
  test_cv_set_signature_pv($sub1, "test2");
	is test_cv_get_signature_pv($sub1), "test2", "But can still be set";
	is test_cv_get_signature_pv(closure2()), undef, "And doesn't impact newly generated closures";
}

# Unicode tests
{
  my $sig;
  my $pound = chr 163;
  test_cv_set_signature_pv(\&bar, $pound);
  $sig = test_cv_get_signature_pv(\&bar);
  is $sig, chr 163, "Set to chr 163";
  is $sig, $pound, "Round tripped properly";
  utf8::encode($pound);
  isnt $sig, $pound, "No longer the same after encoding";
  $sig = test_cv_get_signature_pv(\&bar);
  is $sig, chr 163, "Still chr 163 before resetting";
  test_cv_set_signature_pv(\&bar, $pound);
  $sig = test_cv_get_signature_pv(\&bar);
  isnt $sig, chr 163, "No longer chr 163";
  is $sig, $pound, "Now it matches the UTF-8 encoded form";
}

# Setting values from a magic variable
{
  "Test 2" =~ /(Test)/;
  test_cv_set_signature_pv(\&bar, $1);
	is "Test", test_cv_get_signature_pv(\&bar), "\$1 binds appropriately";
  "test 2" =~ /(test)/;
	is "Test", test_cv_get_signature_pv(\&bar), "But doesn't keep the magic";
}
