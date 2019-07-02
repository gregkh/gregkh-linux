#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-2.0
# (c) 2017 Joe Perches <joe@perches.com>

# script to convert DEVICE_ATTR uses with permissions of 0644 to DEV_ATTR_RW

my $perms_to_match = qr{
	  S_IRUGO\s*\|\s*S_IWUSR
	| S_IWUSR\s*\|\s*S_IRUGO
	| 0644
}x;

my $args_to_match = qr{
	(\w+)\s*,\s*
	\(?\s*($perms_to_match)\s*\)?\s*,\s*
	(\w+)\s*,\s*
	(\w+)
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
	my $store = $4;

	# find the count of uses of the various function names
	my $count_show = () = ($file_copy =~ /\b$show\b/g);
	my $count_store = () = ($file_copy =~ /\b$store\b/g);
	my $count_var_show = () = ($file_copy =~ /\b${var}_show\b/g);
	my $count_var_store = () = ($file_copy =~ /\b${var}_store\b/g);
	my $show_declared = () = ($file_copy =~ /\bstatic\s+ssize_t\s+(?:__ref\s+|__used\s+)?$show\b/g);
	my $store_declared = () = ($file_copy =~ /\bstatic\s+ssize_t\s+(?:__ref\s+|__used\s+)?$store\b/g);

	# if the show/store functions are locally declared
	# rename them to the normal names
	if (($count_show == 2) &&
	    ($count_store == 2) &&
	    ($count_var_show == 0) &&
	    ($count_var_store == 0) &&
	    ($show_declared == 1) &&
	    ($store_declared == 1)) {
	    $file =~ s/\b$show\b/${var}_show/g;
	    $file =~ s/\b$store\b/${var}_store/g;
	}
	my $matched = qr{
			    ${var}\s*,\s*
			    \(?\s*$perms_to_match\s*\)?\s*,\s*
			    ${var}_show\s*,\s*
			    ${var}_store
		    }x;

	# Rename this use
	$file =~ s/\bDEVICE_ATTR\s*\(\s*$matched\s*\)/DEVICE_ATTR_RW(${var})/;
    }
    print $file;
}
