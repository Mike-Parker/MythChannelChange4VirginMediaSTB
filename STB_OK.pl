#! /usr/bin/perl

use strict;

sub backticks_wrapper
{
	my @output = `$_[0]`;
	
	my $exit_status = $?;
	
	return (\@output, $exit_status);
}

sub ddhhmmss2s
{	
	$_[0] =~ /((\d+)-)*((\d+):)*(\d+):(\d+)/o;
		
	return ((60*((60*((24*$2)+$4))+$5))+$6);
}

sub get_process_info
{
	my $process = $_[0];

	my $output_r;
	my $exit_status;
	my %output = ();
	my $etime;

	($output_r, $exit_status) = backticks_wrapper("/bin/bash -c 'ps -C $process -o pid=,etime= 2> /dev/null'");

	if (!$exit_status && scalar(@$output_r) == 1)
	{
		$output_r->[0] =~ s/^\s+//o;
	
		($output{'pid'}, $etime)  = split /\s+/o, $output_r->[0];
				
		$output{'crtime'} = time - ddhhmmss2s($etime);
			
		return \%output;
	}

	print STDERR "ERROR: Retrieval of creation time for $process process failed\n";
	exit(1);
}

my $output_hash_r = get_process_info($ARGV[0]);

my @filenames = ();

for my $i (-1 ..1) 
{
	push @filenames, "/tmp/STB_OK.$output_hash_r->{'pid'}.".($output_hash_r->{'crtime'}+$i);
}

if (!(-e $filenames[0] || -e $filenames[1] || -e $filenames[2]))
{	
	# Specific /tmp/STB_OK file doesn't exist. Clean up /tmp/STB_OK* files left from previous session(s)
	
	unlink(glob("/tmp/STB_OK.*"));
	
	# Check that the STB is up
	
	# Touch /tmp/STB_OK file
	
	open(FH, ">$filenames[1]") or die "Can't create $filenames[1]: $!";
	close(FH);
	
	print "$filenames[1] created\n";
}

print "$filenames[1] exists\n";

# Get on with the channel change	
	


