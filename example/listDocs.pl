#!/usr/bin/perl


use lib '..';
use BitstringSearch;

$databaseName = '/tmp/test1';

$o = BitstringSearch->new();

@list = $o->listAllFiles($databaseName);

foreach $file (@list) {
	print $file . "\n";
}
