#!/usr/bin/perl


use lib '..';
use BitstringSearch;

$databaseName = '/tmp/test1';

$o = BitstringSearch->new();

foreach $argv (@ARGV) {
	$result = $o->insertTextFile(
		'Name'	=> $databaseName,
		'File'	=> $argv
	);

	if($result) {
		print "$argv was inserted\n";
	} else {
		print "Error: $argv\n";
	}
}
