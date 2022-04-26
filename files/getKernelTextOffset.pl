#!/usr/bin/perl

use strict;

my $filename = $ARGV[0];
if( "$filename" eq "") {
    print "Usage: $0 kernel_image_file\n";
    exit 1;
}

open my $fh, '<', $filename or die;
binmode $fh;
seek $fh, 8, 0;
my $buf = "";
read $fh, $buf, 4;
close($fh);
my $str = unpack 'H*', $buf; 
print "$str\n";
exit 0;
