#!/usr/bin/perl -W
#
# convert a stable mbox sent by David Miller to apply to the relevant
# stable kernel tree as a set of patches.
#
# based on c2p, written by me (Greg Kroah-Hartman <greg@kroah.com>)
#

my $line;
my $firstline = "true";
my $header_complete = "false";
my $tmpfile = "";
my $tmpdir;
my $kernel_version;
my $mbox;
my $tmp;


$SIG{__DIE__} = sub
{
	# what usually happens is we don't have the git version, so clean up
	# the temp file we created.
	if ($tmpfile ne "") {
		unlink $tmpfile;
	}
};

sub usage() {
	print "$0 mbox kernel_version\n";
	exit;
}

$numArgs = $#ARGV + 1;
if ($numArgs < 2) {
	usage();
}

# get the mailbox name and test that it is really present
$mbox = shift;
if (!defined($mbox)) {
	usage();
}
unless (-e $mbox) {
	print "$mbox does not exist!\n";
	usage();
}

# get the kernel version and test that we have a stable tree of that name
$kernel_version = shift;
$tmp = "linux-".$kernel_version.".y";
unless (-d $tmp) {
	print "kernel directory $tmp does not exist!\n";
	usage();
}


# create the temp directory we are going to be using
$tmp = "tmpdir_".$kernel_version."_XXXXX";
$tmpdir = `mktemp -d $tmp` || die "Failed to run mktemp";
chomp($tmpdir);

print "tmpdir=\"$tmpdir\"\n";

# Split mbox out into individual messages
`<$mbox formail -ds sh -c 'cat > $tmpdir/msg.\$FILENO'`;

# see if we need to hand-edit anything
$tmp = `grep foo\@bar $tmpdir/*`;
chomp($tmp);
if ($tmp ne "") {
	print "formail has a problem with the mbox, please edit it.\n";
	print "error is:\n\t$tmp\n";
	exit;
}

# all is good, so let's iterate over the files and handle them one-by-one
my @patches = `ls $tmpdir/`;
foreach my $patch (@patches) {
	chomp($patch);
	print "patch = $patch\n";

	# create temp file to copy this one into
	$tmp = "$tmpdir/patch.XXXXX";
	$tmpfile = `mktemp $tmp` || die "failed to run mktemp $tmp";
	print "tmpfile = $tmpfile";

	open FILE, ">$tmpfile" || die "Failed to create $tmpfile";
	open (PATCH, "$tmpdir/$patch") || die "failed to read $patch";

	$firstline = "true";
	$header_complete = "false";
	while ($line = <PATCH>) {
		# We clean up 3 things:
		# 	- Strip the patch number off of the subject
		# 	- add the "From:" line of who wrote the patch
		# 	- add our signed off by

		# clean up the subject line?
		$line =~ s/^Subject: \[PATCH \d\/\d\]/Subject:/;
		$line =~ s/^Subject: \[PATCH \d\d\/\d\d\]/Subject:/;

		# add our signed off by if this is the last line in the header
		if ($line =~ m/^---$/) {
			print FILE "Signed-off-by: Greg Kroah-Hartman <gregkh\@linuxfoundation.org>\n";
		}

		print FILE $line;

		# figure out who wrote this patch
		if ($line =~ m/^From: /) {
			$author = $line;
		}

		# if this is the end of the mail header, write the author info.
		if ($header_complete eq "false") {
			if ($line eq "\n") {
				print FILE "$author\n";
				$header_complete = "true";
			}
		}
	}
	close PATCH;
	close FILE;

	system "vim -c \":set syntax=mail\" $tmpfile";
	system "reset";
	$new_file = `rename-patch $tmpfile`;
	chomp($new_file);
	system "cd ~/linux/stable && ./apply_it $new_file $kernel_version";
}

exit;

