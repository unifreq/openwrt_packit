#!/usr/bin/perl

use strict;
use File::Basename;

our $config_name;
our $config_file;
our $init_file;
if(-f "/etc/config/amlogic") {
	$config_name="amlogic";
	$config_file = "/etc/config/amlogic";
	$init_file = "/etc/init.d/amlogic";
} elsif(-f "/etc/config/cpufreq") {
	$config_name="cpufreq";
	$config_file = "/etc/config/cpufreq";
	$init_file = "/etc/init.d/cpufreq";
} else {
	print "Can not found amlogic or cpufreq config file!\n";
	exit(0);
}

my @policy_ids;
my @policy_names;
my @policy_paths = </sys/devices/system/cpu/cpufreq/policy?>;
if(@policy_paths) {
	foreach my $policy (@policy_paths) {
		push @policy_names, basename($policy);
		push @policy_ids, substr($policy, -1);
	}
} else {
	print "Can not found any policy!\n";
	exit 0;
}

for(my $i=0; $i <= $#policy_ids; $i++) {
	&fix_config_file($policy_ids[$i], $policy_names[$i], $policy_paths[$i]);
}
exit 0;

################################# function ####################################
sub fix_config_file {
	my($id, $name, $path) = @_;
	if($config_name eq "cpufreq") {
		$id = "";
	}

	my %gove_hash = &get_gove_hash($path);
	my @freqs = &get_freq_list($path);
	my %freq_hash = &get_freq_hash(@freqs);
	my $min_freq = &get_min_freq(@freqs);
	my $max_freq = &get_max_freq(@freqs);

	# 如果未设置 governor, 或该 gove 不存在， 则修败默认值为 schedutil
	my $config_gove = &uci_get_by_type($config_name, "settings", "governor" . ${id}, "NA");
	if( ($config_gove eq "NA") ||
	    ($gove_hash{$config_gove} != 1)) {
		&uci_set_by_type($config_name, "settings", "governor" . ${id}, "schedutil");
	}

	# 如果出现不合法的 minfreq, 则修改为实际的 min_freq
	my $config_min_freq = &uci_get_by_type($config_name, "settings", "minifreq" . ${id}, "0");
	if($freq_hash{$config_min_freq} != 1) {
		&uci_set_by_type($config_name, "settings", "minifreq" . ${id}, $min_freq);
	}

	# 如果出现不合法的 maxfreq
	# 或 maxfreq < minfreq, 则修改为实际的 max_freq
	my $config_max_freq = &uci_get_by_type($config_name, "settings", "maxfreq" . ${id}, "0");
	if( ( $freq_hash{$config_max_freq} != 1) || 
            ( $config_max_freq < $config_min_freq)) {
		&uci_set_by_type($config_name, "settings", "maxfreq" . ${id}, $max_freq);
	}
}

sub get_freq_list {
	my $policy_home = shift;
        my @ret_ary;
        open my $fh, "<", "${policy_home}/scaling_available_frequencies" or die;
	$_ = <$fh>;
	chomp;
	@ret_ary = split /\s+/;
	close($fh);
	return @ret_ary;
}

sub get_freq_hash {
	my @freq_ary = @_;
	my %ret_hash;
        foreach my $freq (@freq_ary) {
            if($freq =~ m/\d+/) {
                $ret_hash{$freq} = 1;
            }
        }
	return %ret_hash;
}

sub get_min_freq {
	my @freq_ary = @_;
	return (sort {$a<=>$b} @freq_ary)[0];
}

sub get_max_freq {
	my @freq_ary = @_;
	return (sort {$a<=>$b} @freq_ary)[-1];
}

sub get_gove_hash {
	my $policy_home = shift;
	my %ret_hash;
        open my $fh, "<", "$policy_home/scaling_available_governors" or die;
	$_ = <$fh>;
	chomp;
	my @gov_ary = split /\s+/;
	foreach my $gov (@gov_ary) {
		#print "gov: $gov\n";
		if($gov =~ m/\w+/) {
			$ret_hash{$gov} = 1;
            	}
        }
        close($fh);
	return %ret_hash;
}

sub uci_get_by_type {
	my($config,$section,$option,$default) = @_;
	my $ret;
        $ret=`uci get ${config}.\@${section}[0].${option} 2>/dev/null`;
	# 消除回车换行
	$ret =~ s/[\n\r]//g;
	if($ret eq '') {
		return $default;
	} else {
		return $ret;
	}
}

sub uci_set_by_type {
	my($config,$section,$option,$value) = @_;
	my $ret;
	system("uci set ${config}.\@${section}\[0\].${option}=${value} && uci commit ${config}");
	return;
}
