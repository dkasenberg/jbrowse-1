#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "lib";

use Getopt::Long;
use Data::Dumper;
use Bio::Graphics::JBrowser::Gbrowse_ConvertConfig;

my $confFile;
my $outdir = '/var/lib/jbrowse/conf/DB';

GetOptions("conf=s" => \$confFile,
	   "out=s" => \$outdir,);

if (!defined($confFile)) {
print <<HELP;
USAGE: $0 --conf <conf file> [--out <output directory>]
<conf file>: path to the configuration file
<output directory>: directory where output should go
default: $outdir
HELP
exit;
}

unless (-d "$outdir") { 
	print "There is a no such directory: $outdir\n";
	exit;
}

my %json_conf_files = Bio::Graphics::JBrowser::Gbrowse_ConvertConfig->new($confFile);
print "Created configuration file(s):\n";
my $out_path;
foreach my $filename ( keys %json_conf_files ) {
	$out_path = $outdir."\/".$filename; 
	unless(-e "$out_path\.json"){
		open(my $fout, ">", "$out_path\.json") or die "Couldn't open: $!";
		print $fout $json_conf_files{$filename};
		close($fout);
		print "\t\t\t\t $out_path\.json\n";
	}else{
		my $file_count = 1;
		while($file_count<10) {
			unless(-e $out_path."$file_count\.json"){
				open(my $fout, ">", "$out_path$file_count\.json") or die "Couldn't open: $!";
				print $fout $json_conf_files{$filename};
				close($fout);
				print "\t\t\t\t$out_path$file_count\.json\n";
				last;
			}
			$file_count++;
		}
 	}
}

=head1 AUTHOR

Adam Wright E<lt>Adam.Wright@oicr.on.ca<gt>

Copyright (c) 2007-2011 The Evolutionary Software Foundation

This package and its accompanying libraries are free software; you can
redistribute it and/or modify it under the terms of the LGPL (either
version 2.1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text.

=cut
