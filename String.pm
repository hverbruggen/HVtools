package HVtools::String;
use strict;
use warnings;

use Exporter qw(import);
our @ISA =   qw(Exporter);
our @EXPORT = qw(
	random_digits
	get_spaces
	get_date_time
	
	format_hash
	
	common_start_string
	present_in_all
);

################################################################################################################################################
# functions that return a given number of spaces, random digits, date and time, etc.
################################################################################################################################################

# returns a string containing the requested number of random digits
sub random_digits {
	my $nr = shift;
	my $out = '';
	for (my $i = 0; $i < $nr; ++$i) {$out .= int rand 10;}
	return $out;
}

# returns a string containing the requested number of spaces
sub get_spaces {
	my $nr = shift;
	my $out = '';
	for (my $i = 0; $i < $nr; ++$i) {$out .= ' ';}
	return $out;
}

# returns a string containing the date and time
sub get_date_time {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $a = sprintf "%4d-%02d-%02d_%02d-%02d-%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec;
	return $a;
}


################################################################################################################################################
# functions that format data structures for printing
################################################################################################################################################

# formats a hash for printing
sub format_hash {
	my $in = shift;
	my $indent = shift;
	my $max_key_len = 0;
	foreach my $key (sort keys %$in) {
		if (length $key > $max_key_len) {$max_key_len = length $key}
	}
	my $out = '';
	foreach my $key (sort keys %$in) {
		$out .= get_spaces($indent).$key.get_spaces($max_key_len + 2 - length($key)).$in->{$key}."\n";
	}
	return $out;
}


################################################################################################################################################
# string matching functions
################################################################################################################################################

# goes through an array of strings, returning whatever characters the string have in common on the left side
sub common_start_string {
	my $in = shift;
	if (scalar @$in == 1) {return $in->[0]}
	my $ref = shift @$in;
	for (my $i = length($ref); $i >= 0; $i -= 1) {
		my $substring = substr($ref,0,$i);
		if (present_in_all($substring,$in)) {
			$substring =~ s/\.$//;
			return $substring;
		}
	}
	return "";
}

# checks if a query string is present on the left side of each of an array of other strings
sub present_in_all {
	my $query = shift;
	my $db = shift;
	foreach my $el (@$db) {
		unless ($el =~ /^$query/) {return 0}
	}
	return 1
}


1;