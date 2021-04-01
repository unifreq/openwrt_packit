#!/usr/bin/env perl
#use strict;
use utf8;
binmode(STDOUT, ":utf8");

sub get_soc_temp {
    my @fnames=(
          '/sys/devices/virtual/thermal/thermal_zone0/temp',
          '/sys/devices/platform/scpi/scpi:sensors/hwmon/hwmon0/temp1_input',
       );
    my $fh;
    my $temp = "Unknown";
    for my $fname (@fnames) {
        if( -f $fname ) {
            open $fh, "<", $fname;
            $temp = sprintf "%0.1f℃", <$fh> / 1000;
            close $fh;
            return $temp;
        }
    }
    return $temp;
}

sub get_cpu_freq {
    my @fnames=(
           '/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq',
           '/sys/devices/system/cpu/cpufreq/policy1/cpuinfo_cur_freq',
           '/sys/devices/system/cpu/cpufreq/policy2/cpuinfo_cur_freq',
    );

    my $fh;
    my $freq = "";
    for my $fname (@fnames) {
        if( -f $fname ) {
            open $fh, "<", $fname;
	    if($freq eq "") {
               $freq = sprintf "%dMhz", <$fh> / 1000;
    	    } else {
               $freq = sprintf "(%s & %dMhz)", $freq, <$fh> / 1000;
	    }
	    close $fh;
        }
    }
    return $freq;
}

print  &get_cpu_freq, " / ", &get_soc_temp, "\n";
