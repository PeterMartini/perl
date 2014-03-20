package error;

use overload '""' => sub { $_[0][0] };
1;
