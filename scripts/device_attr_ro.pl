#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-2.0
# (c) 2017 Joe Perches <joe@perches.com>

# script to convert DEVICE_ATTR uses with permissions of 0444 to DEV_ATTR_RO

my $perms_to_match = qr{
	  S_IRUGO
	| 0444
}x;

my $args_to_match = qr{
	(\w+)\s*,\s*
	\(?\s*($perms_to_match)\s*\)?\s*,\s*
	(\w+)\s*,\s*
	NULL
}x;

local $/;

while (<>) {
    my $file = $_;
    my $file_copy = $file;

    # strip comments from file_copy (regex from perlfaq)
    $file_copy =~ s#/\*[^*]*\*+([^/*][^*]*\*+)*/|//([^\\]|[^\n][\n]?)*?\n|("(\\.|[^"\\])*"|'(\\.|[^'\\])*'|.[^/"'\\]*)#defined $3 ? $3 : ""#gse;

    # for each declaration of DEVICE_ATTR
    while ($file =~ m/\bDEVICE_ATTR\s*\(\s*$args_to_match\s*\)/g) {
	my $var = $1;
	my $perms = $2;
	my $show = $3;

	# find the count of uses of the various function names
	my $count_show = () = ($file_copy =~ /\b$show\b/g);
	my $count_var_show = () = ($file_copy =~ /\b${var}_show\b/g);
	my $show_declared = () = ($file_copy =~ /\bstatic\s+ssize_t\s+(?:__ref\s+|__used\s+)?$show\b/g);

	# if the show function is locally declared
	# rename it to the normal name
	if (($count_show == 2) &&
	    ($count_var_show == 0) &&
	    ($show_declared == 1)) {
	    $file =~ s/\b$show\b/${var}_show/g;
	}
	my $matched = qr{
			    ${var}\s*,\s*
			    \(?\s*$perms_to_match\s*\)?\s*,\s*
			    ${var}_show\s*,\s*
			    NULL
		    }x;

	# Rename this use
	$file =~ s/\bDEVICE_ATTR\s*\(\s*$matched\s*\)/DEVICE_ATTR_RO(${var})/;
    }
    print $file;
}
