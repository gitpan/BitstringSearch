#!/usr/bin/perl


use lib '..';
use BitstringSearch;

$databaseName = '/tmp/test1';

$o = BitstringSearch->new();

foreach $argv (@ARGV) {
	$result = $o->removeTextFile(
		'Name'	=> $databaseName,
		'File'	=> $argv
	);

	if($result) {
		print "$argv was removed\n";
	} else {
		print "Error: $argv\n";
	}
}
