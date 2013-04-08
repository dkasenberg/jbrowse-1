package Bio::JBrowse::Cmd::GBrowseConvert;

=head1 NAME

Bio::JBrowse::Cmd::GBrowseConvert - attempt to convert GBrowse configurations to JBrowse configurations

=cut

use strict;
use warnings;

use base 'Bio::JBrowse::Cmd';
use Pod::Usage;

use Bio::JBrowse::JSON;

use Bio::Graphics::FeatureFile;

my $default_feature = 'feature2';

sub option_defaults {(
    out => 'data',
    chunksize => 20_000,
    seqType => 'DNA'
)}

sub option_definitions {(
    "out=s",
    "conf=s",
    "noseq",
    "gff=s",
    "chunksize=s",
    "fasta=s@",
    "refs=s",
    "refids=s",
    "compress",
    "trackLabel=s",
    "seqType=s",
    "key=s",
    "help|h|?",
    "nohash"
)}


sub new {
	my $configFile = Bio::Graphics::FeatureFile->new(-file => $_[1]);
	my @Jbrowse_track_options = (
				     "track", 
				     "key",
				     "autocomplete",
				     "category",
				     "description",
				     "phase", 
				     "subfeatures", 
				     "subfeatureClasses",
				     "arrowheadClass",
				     "feature",
				     "class"
				    );
	my (%config, @array);
	foreach my $stanza ($configFile->setting) {
		foreach my $opt ($configFile->setting($stanza)) {
			if(($stanza =~ /general/) || ($stanza =~ /:database/)){
				$config{$stanza}{$opt} = $configFile->setting($stanza => $opt);
			}
			elsif( $opt eq 'feature' ) {
				@array = ();
				push(@array, $configFile->setting($stanza => $opt));
				$config{$stanza}{$opt} = [ @array ];
			} elsif( $opt eq 'glyph' ) {
				if( $configFile->setting($stanza => $opt) eq 'generic' ) {
					$config{$stanza}{class} = $default_feature;
				}
				else {
					$config{$stanza}{class} = $configFile->setting($stanza => $opt);
				}	
			} 
			elsif( ( grep { $_ eq $opt } @Jbrowse_track_options)||($opt eq 'database') ) {
				$config{$stanza}{$opt} = $configFile->setting($stanza => $opt);
			}
		}
	}
	my $description = "description";
	if(exists $config{general}{description}) {
		$description = $config{general}{description};
	}
	elsif(exists $config{general}{metadata}) {
		$description = $config{general}{metadata};
	}
	
	my $general_db = 0;
	my $general_adaptor = 0;
	my $db_count = 0;
	my (@db_name, @db_adaptor, @db_args, $default_db, %db_args, $conf_args, @args, @arg);
	if(exists $config{general}{database}) {
		$default_db = $config{general}{database}; 
	}
	elsif((exists $config{general}{db_adaptor})&&(exists $config{general}{db_args})) { 
		$general_db = substr($_[1], 0, rindex($_[1],'.'));
		push( @db_name, $general_db);
		push( @db_adaptor, $config{general}{db_adaptor});
		$conf_args = $config{general}{db_args};
		@args = split(' -', $conf_args);
		foreach my $arguement (@args) {
			@arg = split(' ', $arguement);
			$arg[0] =~ s/^-//;
			$arg[0] =~ s/^/-/;
			$db_args[0]{$arg[0]} = $arg[1];
		}
		$db_count = 1;
	}	

	my $tracks_count = 0;
	my (@tracks, $conf_arg);
	for my $stanza (keys %config) {
		if($stanza =~ /:database/){
			push(@db_adaptor, $config{$stanza}{db_adaptor});
			$conf_arg = $config{$stanza}{db_args};
			@args =  split(' -', $conf_arg) ;
			foreach my $argument (@args) {
				@arg =  split(' ', $argument);
				$arg[0] =~ s/^-//;
				$arg[0] =~ s/^/-/;
				$db_args[$db_count]{$arg[0]} = $arg[1];
			}
			$stanza =~ s/:database$//;
			push(@db_name, $stanza);
			$db_count++;
		}
		elsif((!(($stanza =~ /TRACK DEFAULTS/)||($stanza =~ /general/)))
										&&(exists $config{$stanza}{feature})){
			$tracks[$tracks_count]{'track'} = $stanza;
			while (my ($key,$value) = each %{ $config{$stanza} } ) {
				$tracks[$tracks_count]{$key} = $value;
				if(($default_db)&&!(exists $config{$stanza}{'database'})) {
					$tracks[$tracks_count]{'database'} = $default_db;
				}
				elsif(($general_db)&&!(exists $config{$stanza}{'database'})) {
					$tracks[$tracks_count]{'database'} = $general_db;
				}
			}
			$tracks_count++;
		}
	}
	my ($json, %file_info, %json_config_files, $i, @file_tracks, $count);
	my $json_text = Bio::JBrowse::JSON->new;
	# The sort_by function needs be be figured out in order to have the sections 
	# in the proper order
	for ($count = 0; $count < $db_count; $count++){
		$file_info{description} = $description;
		$file_info{db_adaptor} = $db_adaptor[$count];
		$file_info{db_args} = \%{ $db_args[$count] };
		$file_info{'TRACK DEFAULTS'} = \%{ $config{'TRACK DEFAULTS'} };
		@file_tracks = ();
		foreach $i ( 0 .. $#tracks){
			if(($tracks[$i]{database})&&(($tracks[$i]{database}) eq ($db_name[$count]))) { 
				delete $tracks[$i]{database};
				push(@file_tracks, \%{ $tracks[$i] });
			}
		}
		$file_info{tracks} = \@file_tracks;
		$json = $json_text->encode( \%file_info );
		$json_config_files{$db_name[$count]} = $json;
	}
	return %json_config_files;
}

sub custom_sort {
	 my $order = {
		  "description"    	=> 0,
		  "db_adaptor"     	=> 1,
		  "db_args"        	=> 2,
		  "TRACK DEFAULTS" 	=> 3,
		  "tracks"	   		=> 4,
		    };
	return $order->{$a} <=> $order->{$b};
}
	
=head1 AUTHOR

Adam Wright E<lt>Adam.Wright@oicr.on.ca<gt>

Copyright (c) 2007-2011 The Evolutionary Software Foundation

This package and its accompanying libraries are free software; you can
redistribute it and/or modify it under the terms of the LGPL (either
version 2.1, or at your option, any later version) or the Artistic
License 2.0.  Refer to LICENSE for the full license text.

=cut

1;
