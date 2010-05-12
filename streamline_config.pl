#!/usr/bin/perl -w
#
# Copywrite 2005-2008 - Steven Rostedt
# Licensed under the terms of the GNU GPL License version 2
#
#  It's simple enough to figure out how this works.
#  If not, then you can ask me at rostedt@goodmis.org
#
# What it does?
#
#   If you have installed a Linux kernel from a distribution
#   that turns on way too many modules than you need, and
#   you only want the modules you use, than this program
#   is perfect for you.
#
#   It gives you the ability to turn off all the modules that are
#   not loaded on your system.
#
# Howto:
#
#  1. Boot up the kernel that you want to stream line the config on.
#  2. Change directory to the directory holding the source of the
#       kernel that you just booted.
#  3. Copy the configuraton file to this directory as .config
#  4. Have all your devices that you need modules for connected and
#      operational (make sure that their corresponding modules are loaded)
#  5. Run this script redirecting the output to some other file
#       like config_strip.
#  6. Back up your old config (if you want too).
#  7. copy the config_strip file to .config
#  8. Run "make oldconfig"
#
#  Now your kernel is ready to be built with only the modules that
#  are loaded.
#
# Here's what I did with my Debian distribution.
#
#    cd /usr/src/linux-2.6.10
#    cp /boot/config-2.6.10-1-686-smp .config
#    ~/bin/streamline_config > config_strip
#    mv .config config_sav
#    mv config_strip .config
#    make oldconfig
#
my $config = ".config";
my $linuxpath = ".";

# taken from top level kernel Makefile
my $rcs_find_ignore = "\\( -name SCCS -o -name BitKeeper -o -name .svn -o -name CVS -o -name .pc -o -name .hg -o -name .git \\) -prune -o";
my $find_cmd = "$linuxpath $rcs_find_ignore \\( -name \'Makefile*\' -o -name 'Kbuild\' \\) ";

open(CIN,$config) || die "Can't open current config file: $config";
my @makefiles = `find $find_cmd`;

my %objects;
my $var;
my $cont = 0;

foreach my $makefile (@makefiles) {
	chomp $makefile;

	open(MIN,$makefile) || die "Can't open $makefile";
	while (<MIN>) {
		my $catch = 0;

		if ($cont && /(\S.*)$/) {
			$objs = $1;
			$catch = 1;
		}
		$cont = 0;

		if (/obj-\$\((CONFIG_[^)]*)\)\s*[+:]?=\s*(.*)/) {
			$var = $1;
			$objs = $2;
			$catch = 1;
		}
		if ($catch) {
			if ($objs =~ m,(.*)\\$,) {
				$objs = $1;
				$cont = 1;
			}

			foreach my $obj (split /\s+/,$objs) {
				$obj =~ s/-/_/g;
				if ($obj =~ /(.*)\.o$/) {
					$objects{$1} = $var;
				}
			}
		}
	}
	close(MIN);
}

my %modules;

open(LIN,"/sbin/lsmod|") || die "Cant lsmod";
while (<LIN>) {
	next if (/^Module/);  # Skip the first line.
	if (/^(\S+)/) {
		$modules{$1} = 1;
	}
}
close (LIN);

my %configs;
foreach my $module (keys(%modules)) {
	if (defined($objects{$module})) {
		$configs{$objects{$module}} = $module;
	} else {
		print STDERR "$module config not found!!\n";
	}
}

while(<CIN>) {
	if (/^(CONFIG.*)=m/) {
		if (defined($configs{$1})) {
			print;
		} else {
			print "# $1 is not set\n";
		}
	} else {
		print;
	}
}
close(CIN);
