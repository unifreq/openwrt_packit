#!/usr/bin/perl

while(<>) {
	chomp;
	if(/^macaddr=([0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2})$/) {
		print "$1\n";
	}
}
