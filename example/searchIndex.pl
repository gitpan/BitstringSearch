#!/usr/bin/perl

use lib '..';
use BitstringSearch; 
use Benchmark;

$o = BitstringSearch->new(); 
 
# look for words in test1 that equal the command line arguments
foreach $argv (@ARGV) {

	$time0 = new Benchmark;
	@list = $o->searchWord( 
		Name    => '/tmp/test1', 
		Word    => $argv
	); 
	$time1 = new Benchmark;
	$timed = timediff($time1, $time0);
	push(@times, 'Total docs containing ' . $argv . ":\t " . scalar @list . "\t" . timestr($timed) . "\n");

	# print the docs found that contain argvs
	#for(@list) { print $_ . "\n"; } 

}

print "\n\n======= Times =======\n\n";
print @times;
print "\n\n=====================\n\n";


