#!/usr/bin/perl


use lib '..';
use BitstringSearch;
use Benchmark;


$databaseName = '/tmp/test1';
$totalDocs = 500;
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
