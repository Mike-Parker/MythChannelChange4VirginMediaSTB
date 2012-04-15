#! /usr/bin/perl

use strict;

use Channel_Change;
use Getopt::Long;

my $channel;
my $process = "mythbackend";
my $logfile = "/var/log/mythtv/channel_change.log";
 
usage() if ( @ARGV < 1 or !GetOptions('c=i' => \$channel, 'p:s' => \$process));
 
sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "usage: STB_OK.pl -c <numeric_channel> -p <process_name (default: mythbackend)>\n";
  exit;
}

append_to_log("Request received to change channel to $channel", $logfile);

# Retrieve PID and creation time for named process

my $output_hash_r = get_process_info($process, $logfile);

append_to_log("$process process identified (PID: $output_hash_r->{'pid'}, creation time: $output_hash_r->{'crtime'})", $logfile);
	
# Check for existence of /tmp/STB_OK file

my ($exists, $file) = check_tmp_file_existence($output_hash_r);

if (!$exists)
{	
	append_to_log("Specific /tmp/STB_OK.* file not found => status of STB is currently unknown", $logfile);

	# Specific /tmp/STB_OK file doesn't exist. Clean up /tmp/STB_OK* files left from previous session(s)
	
	my @files_to_delete = glob("/tmp/STB_OK.*");
	
	my $num_files = scalar(@files_to_delete);
	
	if ($num_files > 0)
	{
		append_to_log("Cleaning up $num_files old /tmp/STB_OK.* files", $logfile);	
	
		unlink(@files_to_delete);
	}
	
	# Check that the STB is up
	
	append_to_log("Checking STB for recordable output", $logfile);	
		
	my $tests_r 	= [["Box off", undef, undef, undef, undef, "p", undef]];
	my $results_r	= {};
	my $pwrstate 	= 1;
	
	my $fail_test = run_tests($tests_r, $results_r, $logfile);
	
	if ($fail_test != 0)
	{		
		append_to_log("STB Failed test '$fail_test->[0]'", $logfile);
		append_to_log("Sending keypress '".$fail_test->[5]."' to STB", $logfile);
		
		$pwrstate = ($fail_test->[0] eq "Box off" ? 0 : $pwrstate);
		
		my $command_string = "/usr/bin/sudo /usr/local/bin/change_channel.sh ".$fail_test->[5];
		
		#my (undef, $exit_status) = backticks_wrapper("/bin/bash -c '$command_string 2> /dev/null'");
		
		### DEBUG ##########################################################################
	
		my $exit_status = 0;
		
		####################################################################################
		
		if (!$exit_status)
		{
			append_to_log("Keypress '".$fail_test->[5]."' successfully sent to STB. Will retest in 5 seconds", $logfile);
			
			sleep 5;
			
			my $fail_test2 = run_tests($tests_r, $results_r, $logfile);
			
			if ($fail_test2 != 0)
			{
				append_to_log("STB Failed test '$fail_test2->[0]' after 5 seconds. Exiting", $logfile);
				exit(1);
			}			
		}
		else
		{
			append_to_log("Error occurred whilst sending keypress to STB. Exiting", $logfile);
			exit(1);
		}		
	}

	append_to_log("STB confirmed as up", $logfile);
	
	# Touch /tmp/STB_OK file
	
	my $filename = "/tmp/STB_OK.$output_hash_r->{'pid'}.$output_hash_r->{'crtime'}.$pwrstate";
		
	open(FH, ">$filename") or die "Can't create $filename: $!";
	close(FH);
	
	append_to_log("Created $filename", $logfile);		
}
else
{
	append_to_log("$file found", $logfile);
	append_to_log("STB confirmed as up", $logfile);
}

# Get on with the channel change	

