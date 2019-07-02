#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-2.0
# (c) 2017 Joe Perches <joe@perches.com>

# script to convert DEVICE_ATTR uses with permissions of 0644 to DEV_ATTR_RW

my $perms_to_match = qr{
	  S_IWUSR
	| 0200
}x;

my $args_to_match = qr{
	(\w+)\s*,\s*
	\(?\s*($perms_to_match)\s*\)?\s*,\s*
	NULL\s*,\s*
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
	my $store = $3;

	# find the count of uses of the various function names
	my $count_store = () = ($file_copy =~ /\b$store\b/g);
	my $count_var_store = () = ($file_copy =~ /\b${var}_store\b/g);
	my $store_declared = () = ($file_copy =~ /\bstatic\s+ssize_t\s+(?:__ref\s+|__used\s+)?$store\b/g);

	# if the store function is locally declared
	# rename it to the normal name
	if (($count_store == 2) &&
	    ($count_var_store == 0) &&
	    ($store_declared == 1)) {
	    $file =~ s/\b$store\b/${var}_store/g;
	}
	my $matched = qr{
			    ${var}\s*,\s*
			    \(?\s*$perms_to_match\s*\)?\s*,\s*
			    NULL\s*,\s*
			    ${var}_store
		    }x;

	# Rename this use
	$file =~ s/\bDEVICE_ATTR\s*\(\s*$matched\s*\)/DEVICE_ATTR_WO(${var})/;
    }
    print $file;
}
