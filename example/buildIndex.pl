#!/usr/bin/perl


use lib '..';
use BitstringSearch;
use Benchmark;


$databaseName = '/tmp/test1';
$totalDocs = 1000000;
#$wordList = '/usr/share/dict/words';
$wordList = './shortWordList';
$minChars = 3;

$o = BitstringSearch->new();

# create the index to search against
$o->initDb(
	'Name'		=> $databaseName,		# database name
	'TotalDocs'	=> $totalDocs,			# max docs to be inserted
	'WordsList'	=> $wordList,			# good word dictionary
	'MinChars'	=> $minChars	 		# minimum characters to index
); 

# use the HOWTOs... should take 5 minutes to index on a P4 1.5 using 1000 for total docs
@tmp = </usr/doc/Linux-HOWTOs/X*HOWTO>;


$t0 = new Benchmark;
foreach $doc (@tmp) {
	$o->insertTextFile(
		'Name'	=> $databaseName,
		'File'	=> $doc
	);
}
$t1 = new Benchmark;
$td = timediff($t1, $t0);
print "the code took: ",timestr($td),"\n";
