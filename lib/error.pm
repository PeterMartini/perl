package error;

use overload '""' => sub {
	my $self = shift;
	my $prev = (defined $self->[1] ? $self->[1] : "");
	"${prev}$self->[0]";
};

package error::syntax { our @ISA = qw(error); }
1;
