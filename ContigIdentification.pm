package HVtools::ContigIdentification;
use strict;
use warnings;

use HVtools::String;
use HVtools::SystemCommands;
use HVtools::PhylogeneticTree;

use Bio::SeqIO;
use Bio::TreeIO;
use File::Spec;
use Cwd;

use Exporter qw(import);
our @ISA =   qw(Exporter);
our @EXPORT = qw(
	taxonomic_identification_of_contig_by_phylogenomic_analysis
);

# identifies contig taxonomically by phylogenomic comparison to reference dataset
sub taxonomic_identification_of_contig_by_phylogenomic_analysis {
	my $contig_file = shift;
	my $seqDB_dir = shift;
	my $output_dir = shift;

	print "\nRunning function taxonomic_identification_of_contig_by_phylogenomic_analysis from HVtools::ContigIdentification\n";

	# check command line dependencies
		my $exe = find_executables(["fasttree","phyutility","prodigal","blastp","mafft","make_alignments.pl","concatenate_alignments.pl"]);
		print "\nExecutables:\n",format_hash($exe,2);

	# get file and directory names formatted as absolute path
		my $home = getcwd;
		$contig_file = File::Spec->rel2abs($contig_file);
		chdir($seqDB_dir); $seqDB_dir = getcwd;
		chdir($home);
		unless (-e $output_dir) {mkdir($output_dir)}
		chdir($output_dir); $output_dir = getcwd;

	# run prodigal to identify CDSs
		print "\nRunning prodigal to extract CDSs from contig.\n";
		my $cmd = $exe->{"prodigal"}." -i $contig_file -d prodigal_nt.fas -a prodigal_aa.fas -o prodigal_gb.gb -p meta";
		print "  running command in ",getcwd,"\n";
		print "  $cmd\n";
		system("$cmd 1> prodigal_screenout.txt 2> prodigal_screenout.txt");
		print "  Done.\n";

	# BLAST CDSs from contig against reference database
		print "\nBLASTing CDSs from contig against reference database.\n";
		$cmd = $exe->{"blastp"}." -max_target_seqs 1 -query prodigal_aa.fas -evalue 0.0000000001 -db $seqDB_dir\/blastdb_aa -outfmt \"6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen\" -out blast_results.txt";
		print "  running command in ",getcwd,"\n";
		print "  $cmd\n";
		system("$cmd 1> blast_screenout.txt 2> blast_screenout.txt");
		print "  Done.\n";

	# interpret BLAST results
		print "\nInterpreting BLAST results.\n";
		my $hits;
		open FH,"blast_results.txt";
		while (my $line = <FH>) {
			$line =~ s/[\r\n]//g;
			my @a = split /\t/,$line;
			if ($a[12]/$a[3] > 0.75) {  # query coverage must be 75% or above
				$a[1] =~ /^(.*?)\|/;
				my $gene = $1;
				$hits->{$gene} = $a[0];
			}
		}
		close FH;
		print "  Contig gave BLAST hits for ",scalar(keys %$hits)," genes.\n";

	# exit if no blast hits
		if (scalar(keys %$hits) < 1) {
			print "\nNo BLAST hits. Probably not a chloroplast sequence. Terminating execution.\n"; exit;
		}

	# make alignments
		print "\nExtracting sequences from contig and building alignments.\n";
		my $prodigal_seqs;
		my $in = Bio::SeqIO->new(-file => "prodigal_aa.fas", -format => 'fasta');
		while (my $seq = $in->next_seq) {
			$prodigal_seqs->{$seq->id} = $seq->seq;
		}
		my $aln_dir = "gene_alignments";
		mkdir($aln_dir);
		chdir($aln_dir);
		open GL,">alignment_files.txt";
		print "  Running MAFFT for each gene.\n";
		foreach my $gene (keys %$hits) {
			print GL "$gene\t$gene\n";
			my $hitname = $hits->{$gene};
			system("cp $seqDB_dir\/$gene\.aa.fas .");
			open FH,">>$gene\.aa.fas";
			print FH ">target_sequence_XX_XX\n",$prodigal_seqs->{$hitname},"\n";
			close FH;
			system($exe->{"mafft"}." $gene\.aa.fas 1> $gene 2> mafft_screenout.$gene\.txt");
		}
		close GL;
		my $taxa;
		foreach my $gene (keys %$hits) {
			open FH,"$gene\.aa.fas";
			while (my $line = <FH>) {
				if ($line =~ /\>(.*?_.*?)_/) {
					$taxa->{$1} = 1;
				}
			}
			close FH;
		}
		open TL,">allowed_species.txt";
		print TL "",join("\n",sort keys %$taxa),"\n";
		print TL "target_sequence_XX_XX\n";
		close TL;
		system("rm -rf aln*");
		system($exe->{"make_alignments.pl"}." -m best 1> make_alignments.screenout.txt 2> make_alignments.screenout.txt");
		my @rr = <aln*>;
		my $dir = $rr[0];
		print "  Done.\n";

	# concatenate alignments and infer tree
		my $outgroups = [];
		print "\nConcatenating alignments and reconstructing tree.\n";
		chdir($dir);
		system($exe->{"concatenate_alignments.pl"}." ".join(".fas ",sort keys %$hits).".fas 1> concatenate_screenout.txt 2> concatenate_screenout.txt");
		system("rm concatenated.nex");
		open OUT,">concatenated_cleaned_up.fas";
		$in = Bio::SeqIO->new(-file => "concatenated.fas", -format => 'fasta');
		while (my $seq = $in->next_seq) {
			unless ($seq->seq =~ /^\-+$/) {
				my $sid = $seq->id; $sid =~ s/[^A-Za-z0-9\_\-\.]/./g;
				print OUT ">",$sid,"\n",$seq->seq,"\n";
				if ($sid =~ /^Cyanobact/) {push @$outgroups,$sid}
			}
		}
		system("cp concatenated_cleaned_up.fas ..");
		chdir("..");
		system($exe->{"fasttree"}." -mlnni 1 -spr 0 -fastest -nosupport concatenated_cleaned_up.fas > concatenated_cleaned_up.fasttree.nwk 2> fasttree.screenout.txt");
		system($exe->{"phyutility"}." -rr -in concatenated_cleaned_up.fasttree.nwk -out concatenated_cleaned_up.rerooted.fasttree.nwk -names ".join(" ",@$outgroups)." 1> phyutility_screenout.txt 2> phyutility_screenout.txt");
		print "  Done.\n";

	# interpret tree
		print "\nInterpreting tree.\n";
		my $tree = Bio::TreeIO->new(-file => "concatenated_cleaned_up.rerooted.fasttree.nwk", -format => 'newick')->next_tree;
		my $related_taxa = get_related_taxa("target_sequence",$tree);
		my $common_start_string = common_start_string($related_taxa);
		print "  Sister taxon: ",$common_start_string,"\n";
		open OUT,">$output_dir\/sister_taxon.txt"; print OUT $common_start_string,"\n"; close OUT;
		chdir($home);
		print "  Done.\n";
		print "\n";
		return $common_start_string;
}

1;
