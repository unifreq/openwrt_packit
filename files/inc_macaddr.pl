#!/usr/bin/perl

my $inc=shift;
$inc = 1 if ( $inc eq "" );

while(<>) {
	chomp;
	if($inc == 0) {
		print uc($_), "\n";
		next;
	}
	my @mac = split /:/;
	foreach(@mac) {
		$_ = uc($_);	
	}

	my $n = hex($mac[-1]);
	$n = ($n + $inc) & 0xff;
	$mac[-1] = sprintf("%02X", $n );

	$" = ':';
	print "@mac\n";
}
