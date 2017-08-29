#!/bin/perl
#
# make kernel shortlog
#
# Copyright 2017 Greg Kroah-Hartman <gregkh@linuxfoundation.org>
#
# released under the GPLv2 only
#
# SPDX-License-Identifier: GPL-2.0
#
# Dumb script to generate a shortlog of one kernel release to another, in
# cronological order of commits.  Useful for when you merge in an upstream
# kernel release into your own tree.
#

use warnings;
use strict;

my @version_array;
my $version;
my ($email, $name);
my $line;
my ($major_version, $minor_version, $stable_version, $last_version);

# get the version number of the kernel we are merging from and to, in order to
# diff it properly.  The kernel will give this to us automatically by runing
# 'make kernelversion'

$version = `make kernelversion`;
chomp($version);

@version_array = split /\./, $version;
$major_version  = $version_array[0];
$minor_version  = $version_array[1];
$stable_version = $version_array[2];

$last_version = $stable_version - 1;


# get the email and name of the git committer.  Use the environment variables
# first if they are present, if not, use the git config values, just like git
# ends up doing.

$email = $ENV{"GIT_COMMITTER_EMAIL"};
if ($email eq "") {
	$email = `git config --get user.email`;
	chomp($email);
	$email = "<".$email.">";
}

$name = $ENV{"GIT_COMMITTER_NAME"};
if ($name eq "") {
	$name = `git config --get user.name`;
	chomp($name);
}


# print out the changelog text

print "Merge $version into android-$major_version.$minor_version\n";
print "\n";
print "Changes in $major_version.$minor_version.$stable_version\n";

open GIT, "git log --format=\"%s\" --reverse v$major_version.$minor_version.$last_version..v$major_version.$minor_version.$stable_version | " || die "Failed to run git";

while ($line = <GIT>) {
	print "\t$line";
}

close GIT;

print "\n";
print "Signed-off-by: $name $email\n";

exit;
