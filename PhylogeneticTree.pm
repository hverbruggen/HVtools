package HVtools::PhylogeneticTree;
use strict;
use warnings;

use Exporter qw(import);
our @ISA =   qw(Exporter);
our @EXPORT = qw(
	get_related_taxa
);

# given a query taxon name and a tree, this function will return an array with the names of any species in the sister clade of the query taxon
sub get_related_taxa {
	my $taxon = shift;
	my $tree = shift;
	foreach my $leaf ($tree->get_leaf_nodes) {
		if ($leaf->id =~ /^$taxon$/) {
			my $anc = $leaf->ancestor;
			my $out;
			foreach my $desc ($anc->get_all_Descendents) {
				if (($desc->is_Leaf) && !($desc->id =~ /^$taxon$/)) {
					push @$out,$desc->id;
				}
			}
			return $out
		}
	}
	return "";
}

1;