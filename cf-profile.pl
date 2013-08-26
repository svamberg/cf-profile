#!/usr/bin/perl -w

use strict;
use POSIX;
use lib './Time-HiRes-1.9725/lib';
use Time::HiRes;
use Data::Dumper;
use Getopt::Std;

my %data = ();
my $debug = 0;
my $line = "";
my $cur_bundle = "";
my $cur_bundle_key = "";
my $promise_type = "";
my $iter = "";
my $parent_bundle = "";
my @parent = ();
my @parent_keys = ();
my $is_edit_bundle = 0;
$data{start} = Time::HiRes::gettimeofday();
my @b_log = ();

$line = <STDIN>;

if($line =~ /^[a-z]+>/) {
	debug("Found version < 3.5.0");
	prelude_v1();
	bundles_v1();
}
print "===============================================================================\n";
print "Execution tree\n";
print "===============================================================================\n";
print "Start: $data{start} s\n";
print "|\n";
foreach my $b(@b_log){
	my $elapsed = sprintf("%.5f", $data{bundles}{$b}{stop} - $data{bundles}{$b}{start});
	my $rel_start = sprintf("%.5f", $data{bundles}{$b}{start} - $data{start});
	my $rel_stop = sprintf("%.5f", $data{bundles}{$b}{stop} - $data{start});
	my $tab = "      "x$data{bundles}{$b}{level};
	my $header = "-----"x$data{bundles}{$b}{level};
	print "|$header> $b\n";
	print "|$tab"."$tab"."Start: $data{bundles}{$b}{start} s\n";
	print "|$tab"."$tab"."Stop: $data{bundles}{$b}{stop} s\n";
	print "|$tab"."$tab"."Elapsed: $elapsed s\n";
	print "|$tab"."$tab"."Relative start: $rel_start s\n";
	print "|$tab"."$tab"."Relative stop: $rel_stop s\n";

	foreach my $p(@{$data{bundles}{$b}{prtype}}) {
		my $t = ($data{bundles}{$b}{promise_types}{$p}{start})? $data{bundles}{$b}{promise_types}{$p}{start} : "NAN";
		print "|$tab"."$tab"."$tab"."$p\n";
		print "|$tab"."$tab"."$tab"."$tab"."Start: $t s\n";
		if(defined($data{bundles}{$b}{promise_types}{$p}{classes})) {
			print "|$tab"."$tab"."$tab"."$tab"."$tab".join("\n|$tab"."$tab"."$tab"."$tab"."$tab", @{$data{bundles}{$b}{promise_types}{$p}{classes}});
			print "\n";
		}
	}
	print "|\n";
}

$data{stop} = Time::HiRes::gettimeofday();
print "|\n";
print "Stop: $data{stop} s\n";
print "===============================================================================\n";
print "\n";

print "===============================================================================\n";
print "Summary\n";
print "===============================================================================\n";
print "Top 10 worst, bundles:\n";
print "Top 10 worst, promise types:\n";

exit(0);

sub prelude_v1{
	$line = <STDIN>;
	do {
		
		if($line =~ /(Defined|Hard)\s+classes\s+=\s\{\s+(.*)\s+\}/){
			$data{all_classes} = $2;
			debug("Found classes: \"$2\"");
			return 0;
		}
	} while($line = <STDIN>)
}

sub bundles_v1 {
	do {
		if($line =~ /Handling\s+file\s+edits\s+in\s+edit_line\s+bundle/){
			$is_edit_bundle = 1;  
		}
		if($line =~ /\s+BUNDLE\s+(\w+)(\(?\s*\{?[^\}]+\}?\s?\)?)?/){
			if(!$is_edit_bundle) {
				my $bundle = $1;
				my $args = (defined($2))? $2 : "";
				chomp $args;
				if($args) {
					while($line !~ /\'\}\s+\)$/){
						$line = <STDIN>;
						$args .= $line;
					}
				}
				chomp($args);
				debug("Found bundle $bundle $args");
				$cur_bundle = $bundle;
				$cur_bundle_key = $bundle.":".$args;
				$data{bundles}{$cur_bundle_key}{start} = Time::HiRes::gettimeofday();
				$b_log[$#b_log + 1] = $cur_bundle_key;
			}
			$is_edit_bundle = 0;
		} elsif ($line =~ /(\S+)\s+in\s+bundle\s+$cur_bundle\s+\((\d+)\)/){
			$promise_type = $1;
			$iter = $2;
			$data{bundles}{$cur_bundle_key}{prtype}[$#{$data{bundles}{$cur_bundle_key}{prtype}} + 1] = $promise_type.":".$iter;
			$data{bundles}{$cur_bundle_key}{promise_types}{$promise_type.":".$iter}{start} = Time::HiRes::gettimeofday();
			if($promise_type =~ /^methods$/ && ! grep(/$cur_bundle/,@parent)){
				debug("Registering parent $cur_bundle");
				push(@parent,$cur_bundle);
				push(@parent_keys,$cur_bundle_key);
			}
			debug("Found $promise_type in bundle $cur_bundle iter $iter");
		}elsif($line =~ /(Bundle\s+Accounting\s+Summary\s+for|Zero\s+promises\s+executed\s+for\s+bundle)\s+\"(\w+)\"/) {
			my $b = $2;
			debug("End $b");
			if($#parent >= 0 && $parent[$#parent] =~ /$b/) {
				pop(@parent);
				my $p = pop(@parent_keys);
				$data{bundles}{$p}{level} = $#parent + 2;
				$data{bundles}{$p}{stop} = Time::HiRes::gettimeofday();
			}else{
				$data{bundles}{$cur_bundle_key}{stop} = Time::HiRes::gettimeofday();
				$data{bundles}{$cur_bundle_key}{level} = $#parent + 2;
			}
#		}elsif ($line =~ /\s+(\+|\-)\s+(\S+)$/){
#			$data{bundles}{$cur_bundle_key}{promise_types}{$promise_type.":".$iter}{classes}[$#{$data{bundles}{$cur_bundle_key}{promise_types}{$promise_type.":".$iter}{classes}} + 1] = "$1$2";
		}elsif($line =~ /(defining\s+explicit\s+local\s+bundle\s+class\s+|defining\s+promise\s+result\s+class\s+)(\S+)/){
			$data{bundles}{$cur_bundle_key}{promise_types}{$promise_type.":".$iter}{classes}[$#{$data{bundles}{$cur_bundle_key}{promise_types}{$promise_type.":".$iter}{classes}} + 1] = "+$2";
		}
	} while($line = <STDIN>)
}

sub debug {
	my $msg = shift;
	print "DEBUG: $msg\n" if $debug;
}