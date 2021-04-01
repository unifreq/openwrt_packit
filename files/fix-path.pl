#!/usr/bin/perl

use strict;

my @root_mnt_info = &get_mnt_info("/");
my @boot_mnt_info = &get_mnt_info("/boot");

my $root_dev = $root_mnt_info[0];
my $boot_dev = $boot_mnt_info[0];
my $emmc = substr($root_dev, 0, -2);

print "$root_dev $boot_dev $emmc\n";


####################### sub functions ############################
sub get_mnt_info {
    my $path = shift;
    $path = "/" unless $path;
    open FIN, "<", "/proc/mounts" or die;
    while(<FIN>) {
        chomp;
	my @mount_ary = split;
	if($mount_ary[1] eq $path) {
		close FIN;
		return @mount_ary;
	}
    }
    close FIN;
    return;
}
