#!/usr/bin/perl

use strict;
use File::Copy qw(move);

my $policy_home="/sys/devices/system/cpu/cpufreq/policy0";
my $ondemand_home="/sys/devices/system/cpu/cpufreq/ondemand";

our %freqs;
our %goves;
our $min_freq;
our $max_freq;

&get_freq_list;
&get_governor_list;
&fix_init_script;
&fix_config_file;
exit(0);

############### subs ##################
sub get_freq_list {
	my $fh;
	my @ret_ary;
	open $fh, "<", "$policy_home/scaling_available_frequencies" or die;
	while(<$fh>) {
	    chomp;
	    my @freq_ary = split;
	    $min_freq = $freq_ary[0];
	    $max_freq = $freq_ary[-1];
	    foreach my $freq (@freq_ary) {
	        if($freq =~ m/\d+/) {
	            $freqs{$freq} = 1;
                }
            }
	}
	close $fh;
}

sub get_governor_list {
	my $fh;
	open $fh, "<", "$policy_home/scaling_available_governors" or die;
	while(<$fh>) {
	    chomp;
	    my @gov_ary = split;
	    foreach my $gov (@gov_ary) {
	        if($gov =~ m/[a-z]+/) {
	            $goves{$gov} = 1;
                }
            }
	}
	close $fh;
}

sub fix_init_script {
	my $script = "/etc/init.d/cpufreq";
	my $tempfile = "/tmp/cpufreq.temp";
	my $fh_temp;
	my $chg_flag=0;
	open $fh_temp, ">", $tempfile or die; 
	if(-f $script && -x $script) {
	    my $fh;
	    open $fh, "<", $script or die;
	    while(<$fh>) {
		chomp;
		if(m/\(uci_get_by_type settings governor (\w+)\)/) {
			if (not exists $goves{$1}) {
				$_ =~ s/$1/ondemand/;
				$chg_flag = 1;
			}
		} elsif(m/\(uci_get_by_type settings minifreq (\d+)\)/) {
			if (not exists $freqs{$1}) {
				$_ =~ s/$1/$min_freq/;
				$chg_flag = 1;
			}
		} elsif(m/\(uci_get_by_type settings maxfreq (\d+)\)/) {
			if ( (not exists $freqs{$1}) or ($1 < $max_freq) ) {
				$_ =~ s/$1/$max_freq/;
				$chg_flag = 1;
			}
		}
		print $fh_temp "$_\n";
	    }
	    close $fh;
	} 
	close $fh_temp;
	if($chg_flag == 1) {
		print "file $script will be change!\n";
		move $tempfile, $script or die;
		chmod 0755, $script;
	} 
	unlink($tempfile);
}

sub fix_config_file {
	my $config_file = "/etc/config/cpufreq";
	my $tempfile = "/tmp/cpufreq.conf.temp";
	my $fh_temp;
	my $chg_flag=0;
	open $fh_temp, ">", $tempfile or die; 
	if(-f $config_file) {
	    my $fh;
	    open $fh, "<", $config_file or die;
	    while(<$fh>) {
		chomp;
		if(m/option governor '(\w+).*'/) {
			if (not exists $goves{$1}) {
				$_ =~ s/$1/ondemand/;
				$chg_flag = 1;
			}
		} elsif(m/option minifreq '(\d+)'/) {
			if (not exists $freqs{$1}) {
				$_ =~ s/$1/$min_freq/;
				$chg_flag = 1;
			}
		} elsif(m/option maxfreq '(\d+)'/) {
			if ( (not exists $freqs{$1}) ) {
				$_ =~ s/$1/$max_freq/;
				$chg_flag = 1;
			}
		}
		print $fh_temp "$_\n";
	    }
	    close $fh;
	} 
	close $fh_temp;
	if($chg_flag == 1) {
		print "file $config_file will be change!\n";
		move $tempfile, $config_file or die;
		chmod 0644, $config_file;
	} 
	unlink($tempfile);
}
