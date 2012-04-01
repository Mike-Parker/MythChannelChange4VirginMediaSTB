#! /usr/bin/perl

use strict;

my $tests_r = [["Box off",		undef,			undef,				undef,	undef,	"p",	"STB_off.mp3"	],
	       ["Blank screen",		"640x480",		"blank.png",			0,	15,	"101",	undef		],
	       ["Logo",			"120x80+28+18", 	"virgin_logo.png",		11,	15,	"t",	undef		],
	       ["Guide bar",		"570x170+33+280",	"guide_bar.png", 		8500,	15,	"t",	undef		],
	       ["Info box",		"210x40+52+133",	"prog_info.png",		150,	15,	"o",	undef		],
	       ["Favourites bar",	"250x30+39+203",	"favourites_bar.png",		55,	25,	"t",	undef		],
	       ["Pay Per View",		"245x175+37+83",	"virgin_logo_large.png",	0,	15,	"101",	undef		],
	       ["Unsubscribed channel",	"570x37+40+170",	"information.png",		0,	15,	"o",	undef		]];

my $results_r = {};

print "\n";

my $command_string;

LOOP:
{
	my $fail_test = run_tests($tests_r, $results_r); 

	report_results($results_r);

	if ($fail_test != 0)
	{
		print "Failing test : ".$fail_test->[0]."\n";
		print "Sending keypress '".$fail_test->[5]."' and retesting\n";
		
		$command_string = "/usr/bin/sudo /usr/local/bin/change_channel.sh ".$fail_test->[5];
		
		#`$command_string`;
		
		if (defined $fail_test->[6])
		{
			$command_string = "/usr/bin/mplayer -ao alsa -really-quiet ".$fail_test->[6];
			`$command_string`;
		}
		
		#redo LOOP;
	}
	else
	{
		print "All OK\n";
	}
}
print "\n";

exit(0);

sub run_tests
{
	my $tests     =	$_[0];
	my $results_r = $_[1];
	
	my $file = undef;
	my $test;
	my $test_name;

	foreach $test (@$tests)
	{
		$test_name = $test->[0];
	
		if (scalar(@$test) != 7)
		{
			print STDERR "STB_DETECT: ERROR: Incorrect number of parameters defined for test '$test_name'. Exiting\n";
			exit(1);
		}

		if ($test_name eq "Box off")
		{
			detect_box_off($results_r);
		}
		else
		{
			$file = (defined $file ? $file : grab_frame());
		
			compare_frame($results_r, $file, $test, "AE");		
		}
		
		return $test if ($results_r->{$test_name}{'result'});
	}

	print STDERR "STB_DETECT: ERROR: Error deleting $file\n" if (defined $file && !unlink $file);
	
	return 0;
}

sub report_results
{
	my $results_r = $_[0];
	
	my $test_name;
	
	print "\n";

	foreach $test_name (keys %$results_r)
	{
		printf "%-20s : %d", $test_name, $results_r->{$test_name}{'result'};
	
		print " @ ".$results_r->{$test_name}{'diff_pixels'} if (defined $results_r->{$test_name}{'diff_pixels'});

		print "\n";		
	}
	
	print "\n";
}

sub backticks_wrapper
{
	my @output = `$_[0]`;
	
	my $exit_status = $?;
	
	return (\@output, $exit_status);
}

sub detect_box_off
{
	my $results_hash = $_[0];

	my ($output_r, $exit_status) = backticks_wrapper("/bin/bash -c 'v4l-info 2>/dev/null'");
	
	if ($exit_status)
	{
		print STDERR "STB_DETECT: v4l-info call failed\n";
		exit(1);
	}
	else
	{	
		my $num = grep(/^\s+signal\s+:\s+0$/o, @$output_r);
	
		$results_hash->{'Box off'}{'result'} = $num;

		return 0;
	}
}

sub grab_frame
{
	my ($filename, $invocation_string);

	$filename = "/tmp/".`/bin/date +%s`;

	chomp $filename;

	$filename .= ".jpeg";

	$invocation_string = "/usr/bin/streamer -q -s 640x480 -o $filename >& /dev/null";

	if (system($invocation_string))
	{
		print STDERR "STB_DETECT: Video frame capture failed\n";
        	exit(1);	
	}
	
	return $filename;
}

sub compare_frame
{
	my $results_hash		= $_[0];
	my $file			= $_[1];
	my $test_array			= $_[2];
	my $metric			= $_[3];
	
	my ($test_name, $geometry, $reference, $diff_pixel_threshold, $fuzz) = @$test_array;

	my ($output_r, $exit_status) = backticks_wrapper("/bin/bash -c '/usr/bin/convert -extract $geometry $file png:- 2>/dev/null | /usr/bin/compare -metric $metric -fuzz $fuzz\% png:- $reference png:- 2>&1 1>/dev/null'");

	# Use quotes to force merging of $output_r contents into text string (rather than reporting size of @$output_r array)

	my $output = "@$output_r";
	
	if ($exit_status == 0 && $output =~ /@/o)
	{
		my ($diff_pixels) = split /\s+@\s+/o, $output;
		
		$results_hash->{$test_name}{'result'} = ($diff_pixels <= $diff_pixel_threshold ? 1 : 0);
		$results_hash->{$test_name}{'diff_pixels'} = $diff_pixels;
		return 0;
	}
	elsif ($exit_status == 256 && $output =~ /images too dissimilar/o)
	{
		$results_hash->{$test_name}{'result'} = 0;

		return 0;
	}
	else
	{
		print STDERR "STB_DETECT: ERROR: Something bad happened! Exit status: $exit_status, Compare output:\n\n$output\n";
		exit(1);
	}
}
