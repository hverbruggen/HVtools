package HVtools::SystemCommands;
use strict;
use warnings;
use File::Which;

use Exporter qw(import);
our @ISA =   qw(Exporter);
our @EXPORT = qw(
	find_executables
);

################################################################################################################################################
# functions to locate executables
################################################################################################################################################

# finds executables with File::Which
sub find_executables {
	my $in = shift;
	my $die = 0;
	my $out;
	foreach my $el (@$in) {
		my $path = which($el);
		if (defined $path) {$out->{$el} = $path} else {print "ERROR -- no executable found for dependency $el\n"; $die = 1;}
	}
	if ($die) {die;}
	return $out;
}

1;