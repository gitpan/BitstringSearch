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
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.02';

use DB_File; 
use Carp; 
use Fcntl; 

sub new { 
	my $class = shift; 
	my $self = {}; 
	bless $self, $class; 
	return $self; 
} 

sub initDb { 
 
	my $self = shift; 
	my %params = @_; 
	my (%db_Name, %db_Data, %db_Rev); 
 
	$self->{'Name'}         = $params{'Name'}; 
	$self->{'TotalDocs'}    = $params{'TotalDocs'}; 
	$self->{'WordsList'}    = $params{'WordsList'}; 
 
	# Database exists 
	croak "Database exists!" if(-e $self->{'Name'}); 
 
	# Create lock  
	open(LOCK, ">$self->{'Name'}" . '_Lock') or croak "Can not create lockfile: $!"; 
 
	# Lock the LOCK 
	unless(flock(LOCK, 2|4)) { 
		carp "Blocking for write-lock"; 
		unless(flock(LOCK, 2)) { 
			croak "Can not get write-lock: $!"; 
		} 
	} 
 
	# Open configuration database 
	tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	$db_Name{'TotalDocs'} = $self->{'TotalDocs'}; 
	$db_Name{'EmptySlot'} = pack("b*", "0" x $self->{'TotalDocs'}); 
	untie %db_Name; 
 
	# Create reverse lookup name 
	tie(%db_Rev, "DB_File", $self->{'Name'} . '_Rev', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	untie %db_Rev; 
 
	# Create database for bitstring 
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
 
	flock(LOCK, 8); 
	close(LOCK); 

}

sub insertTextFile {
 
	my $self = shift;
	my %params = @_; 
	my (%db_Data, %db_Name, %db_Rev);
	my ($cnt, $bit); 
	my ($word, %uniq);
 
	$self->{'Name'}         = $params{'Name'};
	$self->{'File'}         = $params{'File'};
 
	# Create lock 
	open(LOCK, ">$self->{'Name'}" . '_Lock')
		or croak "Can not create lockfile: $!";
 
	# Lock the LOCK
	unless(flock(LOCK, 2|4)) {
		carp "Blocking for write-lock";
		unless(flock(LOCK, 2)) { 
			croak "Can not get write-lock: $!";
		} 
	} 
 
	tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	for($cnt = 0; $cnt < $db_Name{'TotalDocs'}; $cnt++) { 
		$bit = unpack("b", vec($db_Name{'EmptySlot'}, $cnt, 1));
		if(!$bit) { 
			vec($db_Name{'EmptySlot'}, $cnt, 1) = '1';
			last; 
		} 
	} 
	untie(%db_Name);
 
	tie(%db_Rev, "DB_File", $self->{'Name'} . '_Rev', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	$db_Rev{$cnt} = $self->{'File'}; 
	untie(%db_Rev); 
 
	tie(%db_Data, "DB_File", $self->{'Name'} . '_Data', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	open(IN, "< $self->{'File'}")
		or croak "File for insert does not exist: $!"; 
	while(<IN>) { 
		chomp;
		next if(/^$/);
		s/^[\W|0-9|\s]+//;
		s/[\W|0-9|\s]+/ /g;
		s/[\W|0-9|\s]+$//g;
		$_ = lc $_; 
		foreach $word (split(/\s/, $_)) {
			next unless($word =~ /^[a-z_]+$/);
			next if($uniq{$word}); 
			next unless($db_Data{$word});
			$uniq{$word} = 1; 
			vec($db_Data{$word}, $cnt, 1) = 1;
		} 
	} 
	untie(%db_Data);
 
	flock(LOCK, 8);
	close(LOCK); 
 
}

sub searchWord {
 
	my $self = shift;
	my %params = @_; 
	my (%db_Data, %db_Name, %db_Rev);
	my ($tmpCnt, $totalDocs, @list); 
 
	$self->{'Name'}         = $params{'Name'};
	$self->{'Word'}         = $params{'Word'};

	# Create lock 
	open(LOCK, ">$self->{'Name'}" . '_Lock')
		or croak "Can not create lockfile: $!";
 
	# Lock the LOCK
	unless(flock(LOCK, 2|4)) {
		carp "Blocking for write-lock";
		unless(flock(LOCK, 2)) { 
			croak "Can not get write-lock: $!";
		} 
	} 
 
	# Open configuration database
	tie(%db_Name, "DB_File", $self->{'Name'}, O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	$totalDocs = $db_Name{'TotalDocs'}; 
	untie %db_Name; 
 
	tie(%db_Data, "DB_File", $self->{'Name'} . '_Data', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!";
	tie(%db_Rev, "DB_File", $self->{'Name'} . '_Rev', O_RDWR|O_CREAT, 0600, $DB_HASH)
		or croak "Can not open db: $!"; 
	if($db_Data{$self->{'Word'}}) {
		for($tmpCnt = 0; $tmpCnt < $totalDocs; $tmpCnt++) { 
			if(vec($db_Data{$self->{'Word'}}, $tmpCnt, 1)) {
				push(@list, $db_Rev{$tmpCnt}); 
			} 
		} 
	}
	untie(%db_Rev);
	untie(%db_Data);
 
	return @list;
 
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
  $o->initDb( 
    'Name'          => '/tmp/testDatabase',
    'TotalDocs'     => '10000', 
    'WordList'      => '/usr/share/dict/words'
  ); 

  # insert a text file
  $o->insertTextFile(
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
    - WordList	=> list of good words to index

  insertTextFile
    - Name	=> name of database to insert into
    - File	=> name of file to insert

  searchWord
    - Name	=> name of database to search
    - Word	=> return list of document containing Word


=head2 EXPORT

None by default.

=head1 SEE ALSO

Look in the example directory for an example of usage.

=head1 AUTHOR

Richard Zilavec, E<lt>rzilavec@linistrator.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Zilavec

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
