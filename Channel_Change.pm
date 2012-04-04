package Channel_Change;

use strict; 

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(append_to_log backticks_wrapper check_tmp_file_existence get_process_info run_tests);

sub append_to_log
{
	my $string 	= $_[0];
	my $logfile	= $_[1];
	
	open(FH, ">>$logfile") or die "Can't create $logfile: $!";
	
	print FH localtime()." : $string\n";
	
	close(FH);	
	
}

sub backticks_wrapper
{
	my @output = `$_[0]`;
	
	my $exit_status = $?;
	
	return (\@output, $exit_status);
}

sub check_tmp_file_existence
{
	my $hash_r = $_[0];

	my $file;
	my $crtime;

	foreach $file (glob("/tmp/STB_OK.$hash_r->{'pid'}.*"))
	{	
		(undef, undef, $crtime, undef) = split /\./o, $file;
		
		if (abs($crtime - $hash_r->{'crtime'}) <= 1)
		{
			return (1, $file);
		}
	}
	
	return (0, undef);
}

sub ddhhmmss2s
{	
	$_[0] =~ /((\d+)-)*((\d+):)*(\d+):(\d+)/o;
		
	return ((60*((60*((24*$2)+$4))+$5))+$6);
}

sub detect_box_off
{
	my ($results_hash, $logfile) = @_;

	#my ($output_r, $exit_status) = backticks_wrapper("/bin/bash -c 'v4l-info 2>/dev/null'");
	
	### DEBUG ##########################################################################
	
	#open FILE, "v4l-info-no-signal.txt" or die $!;
	open FILE, "v4l-info-signal.txt" or die $!;

	my @file = <FILE>;
	
	close FILE;
	
	my $output_r = \@file;
	my $exit_status = 0;
	
	####################################################################################
	
	if ($exit_status)
	{
		append_to_log("ERROR: v4l-info call failed. Exiting", $logfile);
		
		exit(1);
	}
	else
	{	
		my $num = grep(/^\s+signal\s+:\s+0$/o, @$output_r);
	
		$results_hash->{'Box off'}{'result'} = $num;

		return 0;
	}
}

sub get_process_info
{
	my ($process, $logfile) = @_;

	my %output = ();
	my $etime;

	my ($output_r, $exit_status) = backticks_wrapper("/bin/bash -c 'ps -C $process -o pid=,etime= 2> /dev/null'");

	if (!$exit_status && scalar(@$output_r) == 1)
	{
		$output_r->[0] =~ s/^\s+//o;
	
		($output{'pid'}, $etime)  = split /\s+/o, $output_r->[0];
				
		$output{'crtime'} = time - ddhhmmss2s($etime);
			
		return \%output;
	}

	append_to_log("ERROR: Retrieval of creation time for $process process failed. Exiting", $logfile);
	
	exit(1);
}

sub run_tests
{
	my $tests     =	$_[0];
	my $results_r = $_[1];
	my $logfile   = $_[2];
	
	my $file = undef;
	my $test;
	my $test_name;

	foreach $test (@$tests)
	{
		$test_name = $test->[0];
	
		if (scalar(@$test) != 7)
		{
			append_to_log("ERROR: Incorrect number of parameters defined for test '$test_name'. Exiting", $logfile);
			
			exit(1);
		}

		if ($test_name eq "Box off")
		{
			detect_box_off($results_r, $logfile);
		}
		else
		{
			$file = (defined $file ? $file : grab_frame());
		
			compare_frame($results_r, $file, $test, "AE");		
		}
		
		return $test if ($results_r->{$test_name}{'result'});
	}

	append_to_log("ERROR: Error deleting $file\n", $logfile) if (defined $file && !unlink $file);
	
	return 0;
}

1;
