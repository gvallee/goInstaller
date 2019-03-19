#!/usr/bin/perl
#

#
# Copyright(c)	2019	UT-Battelle, LLC
#			All rights reserved
#

use strict;
use warnings "all";

use Getopt::Long;
use File::Basename;
use Cwd;

my $help = 0; # By default, do not print the help message
my $verbose = 0; # By default, do not enable the verbose mode
my $force = 0; # Bu default, do not enable force mode
my $configfile = undef;
my $scratchdir = undef;
my $destdir = undef;
my $arch = "amd64";
my $moduledir = undef;

GetOptions (
	"help"		=> \$help,
	"verbose"	=> \$verbose,
	"configfile=s"	=> \$configfile,
	"scratchdir=s"	=> \$scratchdir,
	"destdir=s"	=> \$destdir,
	"force"		=> \$force,
	"arch=s"	=> \$arch,
	"moduledir=s"	=> \$moduledir,
);

my $topDir = Cwd::abs_path(dirname (__FILE__)) . "/../..";
my $topSrcDir = "$topDir/src";
my $libDir = "$topDir/src/lib";
push (@INC, $libDir);

# Require some of our packages that are necessary for the rest of the code
require "$libDir/Utils/Fmt.pm";
require "$libDir/Utils/ConfParser.pm";

my %verboseConfig;
my $verboseCfg = \%verboseConfig;
if ($verbose)
{
        $verboseCfg = Utils::Fmt::set_verbosity ($verboseCfg, $verbose);
}

if ($help)
{
	print "Usage: $0 [--configfile=<PATH/TO/CONFIG/FILE>] --moduledir=<MODULEDIR> --destdir=<DESTDIR> --scratchdir=<SCRATCHDIR>] [--arch=<ARCH>] [--help] [--verbose] [--force]\n";
	print "\t--help         This help message\n";
	print "\t--verbose      Enable verbose mode\n";
	print "\t--force        Enable force mode (it will delete all previously created files to restart from scratch)\n";
	print "\t--configfile   Absolute path to a configuration file (by default, $topDir/etc/go_packager.conf)\n";
	print "\t--moduledir    Absolute path to the directory where the module file will be created, i.e., the path given to users to use \"module use\"\n";
	print "\t--scratchdir   Absolute path to the directory where everything will be compiled and prepared before installation\n";
	print "\t--destdir      Destination directory, i.e., where the Go code will be install\n";
	print "\t--arch		Target architecture ($arch by default)\n";
	exit (0);
}



if (!defined $configfile)
{
        $configfile = "$topDir/etc/go_packager.conf";
        Utils::Fmt::vprintln ($verboseCfg, "Configuration file set to: $configfile");
}

# Some sanity checks
die "ERROR: Invalid config file" if (!defined ($configfile) || ! -e $configfile);
die "ERROR: Invalid destination directory" if (!defined ($destdir) || ! -e $destdir);
die "ERROR: Invalid scratch directory" if (!defined ($scratchdir) || ! -e $scratchdir);
die "ERROR: Invalid directory for the modulefile" if (!defined ($moduledir) || ! -e $moduledir);

my $config_ref = Utils::ConfParser::load_config ($configfile);
die "ERROR: Impossible to load the configuration from $configfile" if (!defined ($config_ref));
if ($verbose)
{
	Utils::ConfParser::print_config ($config_ref);
}

my %config = %$config_ref;
my $goSrcUrl = $config{"go_url"};
my $goBootstrapSrcUrl = $config{'go-bootstrap_url'};

require Utils::Exec;
if ($force && -e $scratchdir)
{
	my $cmd = "cd $scratchdir; rm -rf *";
	Utils::Exec::run_cmd ($verboseCfg, $cmd);

	$cmd = "cd $destdir; rm -rf *";
	Utils::Exec::run_cmd ($verboseCfg, $cmd);
}

Utils::Fmt::vlogln ($verboseCfg, "Creating $scratchdir...");
my $cmd = "mkdir -p $scratchdir";
Utils::Exec::run_cmd ($verboseCfg, $cmd);

print "Configuration Summary:\n";
print "-> Top dir of the Go installer: $topDir\n";
print "-> Configuration file: $configfile\n";
print "-> Destination directory: $destdir\n";
print "-> Scratch directory: $scratchdir\n";
print "-> Installing Go from: $goSrcUrl\n";
print "-> Arch: $arch\n";
print "-> Go-bootstrap: $goBootstrapSrcUrl\n";
print "-> Module directory: $moduledir\n";

require "$libDir/Go/Installer.pm";
my %goConfig;
$goConfig{'moduleDir'} = $moduledir;
$goConfig{'topDir'} = $topDir;
$goConfig{'url'} = $goSrcUrl;
$goConfig{'scratch'} = $scratchdir;
$goConfig{'arch'} = $arch;
$goConfig{'bootstrap_url'} = $goBootstrapSrcUrl;
$goConfig{'installDir'} = $destdir;
$goConfig{'moduledir'} = $moduledir;
$goConfig{'force'} = $force;

%goConfig = Go::Installer::install ($verboseCfg, \%goConfig);
Go::Installer::create_modulefile ($verboseCfg, \%goConfig);
