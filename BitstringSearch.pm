package BitstringSearch;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use BitstringSearch ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.05';

use DB_File; 
use Carp; 
use Fcntl; 

#
# new - no arguements
sub new { 
	my $class = shift; 
	my $self = {}; 
	bless $self, $class; 
	return $self; 
} 

#
# initDB - Creates databases
#
#	%db_Name - Main database which holds global settings.
#	%db_Data - Contains a key from the WordsList you provide and
#	           the value is a bitstring the length of TotalDocs.
#	           The index number is hashed in %db_Rev and the value
#	           of the key is the document it represents.
#	%db_Rev  - The key of this database is the index number of the
#	           bitstring from %db_Data and holds the full path to
#	           the document it represents
#	%db_File - Contains a list of all indexed files and the value is
#                  the bitstring index number
sub initDb { 
 
	my $self = shift; 
	my %params = @_; 
	my (%db_Name, %db_Data, %db_Rev, %db_File); 
	my ($lock);
 
	$self->{'Name'}         = $params{'Name'}; 
	$self->{'WordsList'}    = $params{'WordsList'}; 
	$self->{'TotalDocs'}    = $params{'TotalDocs'}	|| 500; 
	$self->{'MinChars'}	= $params{'MinChars'}	|| 4;
 
	# database exists 
	if(-e $self->{'Name'}) { croak "Database exists!"; }

	# wordslist does not exist
	if(! -e $self->{'WordsList'}) { croak "Can not find WordsList: $!"; }

	$lock = _myLock($self->{'Name'});

	tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	$db_Name{'TotalDocs'} = $self->{'TotalDocs'}; 
	$db_Name{'MinChars'} = $self->{'MinChars'};
	$db_Name{'EmptySlot'} = pack("b*", "0" x $self->{'TotalDocs'}); 
	untie %db_Name; 
 
	tie(%db_Data, "DB_File", $self->{'Name'} . '_Data', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	open(IN, $self->{'WordsList'}) or croak "Can open good words list: $!"; 
	while(<IN>) { 
		chomp; 
		$_ = lc($_); 
		$db_Data{$_} = pack("b*", "0" x $self->{'TotalDocs'}); 
	} 
	close(IN); 
	untie %db_Data; 

	tie(%db_Rev, "DB_File", $self->{'Name'} . '_Rev', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	untie %db_Rev; 

	tie(%db_File, "DB_File", $self->{'Name'} . '_File', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	untie %db_File; 
 
	_myUnlock($lock);

	return 1;

}

#
# insertTextFile - inserts a plain text file
#
#	Name - is the name of the database you wish to insert into
#	File - is the name of the file and full path you wish to index
#	
# A lookup is done in %db_Name to get the next free index number to
# insert into and the MinChars allowed to be indexed. The %db_Rev is 
# updated, the file is read in, parsed then each word is checked and
# possibly entered.
#
# This process is WAY too slow.
sub insertTextFile {
 
	my $self = shift;
	my %params = @_; 
	my (%db_Data, %db_Name, %db_Rev, %db_File);
	my ($cnt, $bit, $minChars, $file, @words, $word, %uniq, $lock); 
 
	$self->{'Name'}         = $params{'Name'};
	$self->{'File'}         = $params{'File'};

	$lock = _myLock($self->{'Name'});

	# make sure file is not already checked in
	tie(%db_File, "DB_File", $self->{'Name'} . '_File', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	if($db_File{$self->{'File'}}) {
		untie %db_File;
		_myUnlock($lock);
		return 0;
	} else {
		# find next empty slot and grab global values
		tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
			or croak "Can not open db: $!";
		for($cnt = 0; $cnt < $db_Name{'TotalDocs'}; $cnt++) { 
			$bit = unpack("b", vec($db_Name{'EmptySlot'}, $cnt, 1));
			if(!$bit) { 
				vec($db_Name{'EmptySlot'}, $cnt, 1) = '1';
				last; 
			} 
		} 
		if($bit) {
			croak "Database is full... you must rebuild with a larger TotalDocs";
		}
		$minChars = $db_Name{'MinChars'};
		untie(%db_Name);

		$db_File{$self->{'File'}} = $cnt;

	}
	untie %db_File; 

	tie(%db_Rev, "DB_File", $self->{'Name'} . '_Rev', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	$db_Rev{$cnt} = $self->{'File'}; 
	untie(%db_Rev); 
 
	tie(%db_Data, "DB_File", $self->{'Name'} . '_Data', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	open(IN, "< $self->{'File'}")
		or croak "File for insert does not exist: $!"; 

	undef $/;
	$file = lc <IN>;
	$file =~ s/^[\W|0-9|\s|_]+//; 
	$file =~ s/[\W|0-9|\s|_]+/ /g; 
	$file =~ s/[\W|0-9|\s|_]+$//g; 
	@words = grep { ! $uniq{$_} ++ } split(/\s+/, $file);
	foreach $word (@words) {
		chomp $word;
		next unless($word =~ /^[a-z_]{$minChars,}$/);
		next unless($db_Data{$word});
		my $bs = $db_Data{$word};
		vec($bs, $cnt, 1) = 1;
		$db_Data{$word} = $bs;
	}

	close(IN);
	untie(%db_Data);
 
	_myUnlock($lock);

	return 1;
 
}

# 
# updateTextFile - updates already inserted plain text files
# 
#       Name - is the name of the database you wish to insert into
#       File - is the name of the file and full path you wish to index
#        
# This is almost the same as insertTextFile but all the bitstrings positions
# representing the doc being updated are zero'd first then re-inserted
# 
# This process PAINFULLY slow but it works and is less painful then rebuilding
# an entire new database to replace the current one for a few docs
sub updateTextFile {

	my $self = shift; 
	my %params = @_; 
	my (%db_Data, %db_Name, %db_Rev, %db_File); 
	my ($cnt, $bit, $minChars, $file, @words, $word, %uniq, $lock); 
 
	$self->{'Name'}         = $params{'Name'}; 
	$self->{'File'}         = $params{'File'}; 
 
        $lock = _myLock($self->{'Name'}); 

	tie(%db_File, "DB_File", $self->{'Name'} . '_File', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	if(! defined($db_File{$self->{'File'}})) {
		untie %db_File;
		_myUnlock($lock);
		return 0;
	} else {
		# find next empty slot and grab global values
		tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
			or croak "Can not open db: $!";
		$minChars = $db_Name{'MinChars'};
		untie(%db_Name); 
		$cnt = $db_File{$self->{'File'}};
	} 
	untie %db_File;

	# update the doc
        tie(%db_Data, "DB_File", $self->{'Name'} . '_Data', O_RDWR|O_CREAT, 0600, $DB_HASH)
                or croak "Can not open db: $!"; 

	# set all previous finds to zero
	foreach $word (keys %db_Data) {
		my $bs = $db_Data{$word};
		vec($bs, $cnt, 1) = 0; 
		$db_Data{$word} = $bs;
	}

        open(IN, "< $self->{'File'}") 
                or croak "File for insert does not exist: $!";
 
        undef $/;
        $file = lc <IN>;
        $file =~ s/^[\W|0-9|\s|_]+//;
        $file =~ s/[\W|0-9|\s|_]+/ /g;
        $file =~ s/[\W|0-9|\s|_]+$//g;
        @words = grep { ! $uniq{$_} ++ } split(/\s+/, $file);
        foreach $word (@words) { 
                chomp $word; 
                next unless($word =~ /^[a-z_]{$minChars,}$/);
                next unless($db_Data{$word}); 
                my $bs = $db_Data{$word}; 
                vec($bs, $cnt, 1) = 1; 
                $db_Data{$word} = $bs; 
        } 
 
        close(IN);
        untie(%db_Data);

	_myUnlock($lock);

	return 1;
}

#
# searchWord - returns a list of documents Word
#
#	Name - the database you wish to search in
#	Word - the word you wish to find in Name
#
# %db_Name is opened for global information then Word is looked up in %db_Data
# and the bitstring is checked from end to end. Each bit in the string set to '1'
# is is reversed by %db_Rev, pushed into @list and then returned to the user.
sub searchWord {
 
	my $self = shift;
	my %params = @_; 
	my (%db_Data, %db_Name, %db_Rev);
	my ($tmpCnt, $totalDocs, @list, $tstring); 
	my ($lock);
 
	$self->{'Name'}         = $params{'Name'};
	$self->{'Word'}         = $params{'Word'};

	$lock = _myLock($self->{'Name'});
 
	# Open configuration database
	tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	$totalDocs = $db_Name{'TotalDocs'}; 
	untie %db_Name; 
 
	tie(%db_Data, "DB_File", $self->{'Name'} . '_Data', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	tie(%db_Rev, "DB_File", $self->{'Name'} . '_Rev', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 

	# search the bit string for docs containing word
	if($db_Data{$self->{'Word'}}) {

		# increase the speed by transferring to memory
		$tstring = $db_Data{$self->{'Word'}};
		for($tmpCnt = 0; $tmpCnt < $totalDocs; $tmpCnt++) { 
			if(vec($tstring, $tmpCnt, 1)) { 
				push(@list, $db_Rev{$tmpCnt});
			} 
		}
			
	}

	untie(%db_Rev);
	untie(%db_Data);
 
	_myUnlock($lock);

	return @list;
 
}

sub _myLock {
 
        my $file = shift;
 
        open(LOCK, ">$file" . '_Lock') or croak "Can not create lockfile: $!";
        unless(flock(LOCK, 2|4)) {
                carp "Blocking for write-lock"; 
                unless(flock(LOCK, 2)) {
                        croak "Can not get write-lock: $!";
                } 
        } 
 
        return \*LOCK;
 
} 
 
sub _myUnlock {
 
        my $lock = shift;
 
        flock($lock, 8); 
        close($lock);
 
} 

sub DESTROY {
    my $self = shift ;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

BitstringSearch - Perl extension for indexing text documents

=head1 SYNOPSIS

  use BitstringSearch;

  # get BitstringSearch object
  $o = BitstringSearch->new();

  # create and load database
  $result = $o->initDb( 
    'Name'          => '/tmp/testDatabase',
    'TotalDocs'     => '500', 
    'MinChars'      => '4',
    'WordList'      => '/usr/share/dict/words'
  ); 

  # insert a text file
  $r = $o->insertTextFile(
    'Name'          => '/tmp/testDatabase',
    'File'          => $somefile
  );

  # update an existing text file
  $r = $o->updateTextFile(
    'Name'          => '/tmp/testDatabase',
    'File'          => $somefile
  );
 
  # search for documents containing a specific word
  @list = $o->searchWord( 
    'Name'          => '/tmp/testDatabase',
    'Word'          => 'software' 
  ); 

=head1 DESCRIPTION

Create an indexed database of your text documents using a dictionary
of good words to index.

  initDb
    - Name	=> name of the database
    - TotalDocs	=> total documents database will hold
    - WordList	=> list of good words to index (default 500)
    - MinChars  => minimum characters in a word required for indexing (default 4)

  insertTextFile
    - Name	=> name of database to insert into
    - File	=> name of file to insert

  updateTextFile
    - Name	=> name of database to update into
    - File	=> name of file to update

  searchWord
    - Name	=> name of database to search
    - Word	=> return list of document containing Word


=head2 EXPORT

None by default.

=head1 SEE ALSO

Look in the example directory for an example of usage.

=head1 DEPENDENCIES

  DB_File
  Fcntl

=head1 AUTHOR

Richard Zilavec, E<lt>rzilavec@linistrator.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Zilavec

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
