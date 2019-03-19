#
# Copyright (c)		2019	UT-Battelle, LLC
#				All rights reserved.
#

package Go::Installer;

use strict;
use warnings "all";
use File::Basename;

our @EXPORT_OK = qw(install);

# This function tells us if the file is local (and needs to be copied) or needs to be downloaded from a server
sub get_download_type ($)
{
	my ($url) = @_;

	return "www" if ($url =~ /^http:/ || $url =~ /^https:/);
	return "file" if ($url =~ /^file:/);
	return "git-lfs" if ($url =~ /^git-lfs:/);

	return undef;
}

sub get_package_version ($)
{
	my ($file) = @_;

	my $version = undef;
 	if ($file =~ /[a-z]*[A-Z]*(.*).src./)
 	{       
 		return $1;
 	}
 
 	if ($file =~ /[a-z]*[A-Z]*(.*).tar./)
 	{       
 		return $1;
 	}

	return undef;
}

sub download ($$)
{
	my ($verboseCfg, $ref) = @_;

	return if (!defined ($ref));

	my %config = %$ref;
	my $url = $config{'url'};
	my $destdir = $config{'scratch'};

	require "Utils/Fmt.pm";

	die "ERROR: Undefined URL" if (!defined ($url));
	my $file = File::Basename::basename ($url);
	# We may use a URL such as "go-linux-ppc64le-bootstrap.tbz?raw=true"
	if ($file =~ /(.*)\?(.*)$/) {
		$file = $1;
	}

	my $fullPathFile = "$destdir/$file";
	Utils::Fmt::vlog ($verboseCfg, "Getting $url and copying it to $fullPathFile...");
	if (-e "$fullPathFile")
	{
		Utils::Fmt::vprintln ($verboseCfg, "$fullPathFile already exists; not downloading");
	}
	else
	{
		my $downloadType = get_download_type ($url);
		die ("ERROR: Invalid file type") if (!defined ($downloadType));
		mkdir ($destdir) if (! -e $destdir);

		my $cmd = "cd $destdir; ";
		my $fileType = get_download_type($url);
		$cmd .= "wget  $url" if ($fileType eq "www");
		if ($fileType eq "file")
		{
			my $filepath = $url;
			if ($url =~ /^file:\/\/(.*)/) {
				$filepath = $1;
			}
				
			$cmd .= "cp $filepath $fullPathFile";
		}

		require "Utils/Exec.pm";
		Utils::Exec::run_cmd (undef, $cmd);

		Utils::Fmt::vprintln ($verboseCfg, "Success");
	}

	my $version = get_package_version ($file);

	return $file, $version;
}

sub detect_file_type ($)
{
	my ($file) = @_;

	die ("ERROR: Undefined file") if (!defined ($file));

	return "tarGZ" if ($file =~ /.tar.gz$/ || $file =~ /.tgz$/);
	return "tarBZ" if ($file =~ /.tbz$/);

	return undef;
}

# Each project potentially has a different way to name the directory in a tarball.
# This function abstracts this
sub get_dir_name_from_tarball ($)
{
	my ($ref) = @_;

	return if (!defined ($ref));

	my %config = %$ref;
	my $name = undef;

	# Some sanity checks
	die "ERROR: Undefined architecture" if (!exists ($config{'arch'}) || !defined ($config{'arch'}));
	die "ERROR: Undefined package name" if (!exists ($config{'name'}) || !defined ($config{'name'}));

	# First, special case of go bootstrap
	return "go-linux-$config{'arch'}-bootstrap" if ($config{'name'} eq "go-bootstrap");

	# The Go project always name the directory in the tarball 'go'
	return "go" if (exists ($config{'name'}) && $config{'name'} eq "go");
	
	# Most project will name the directory <package_name>-<version>
	return "$config{'name'}-$config{'version'}" if (exists ($config{'name'}) && exists ($config{'version'}));

	return undef;
}

sub untar ($$)
{
	my ($verboseCfg, $ref) = @_;

	return undef if (!defined ($ref));

	my %config = %$ref;

	my $tarball = $config{'tarball'};
	my $destdir = $config{'scratch'};

	# Some sanity checks
	die "ERROR: Invalid destination directory" if (!defined ($destdir));
	die "ERROR: Undefined tarball" if (!defined ($tarball));

	mkdir ($destdir) if (! -e $destdir);

	require "Utils/Fmt.pm";
	require "Utils/Exec.pm";

	my $name = get_dir_name_from_tarball ($ref);
	die "ERROR: Cannot figure out the directory name from the tarball" if (!defined ($name));

	my $targetDir = "$destdir/$name";
	my $fileType  = detect_file_type ($tarball);
	die "ERROR: Cannot detect the tarball format" if (!defined ($fileType));

	if (! -e $targetDir)
	{
		Utils::Fmt::vlogln ($verboseCfg, "$targetDir does not exist; untaring $tarball...");
		my $cmd = "cd $destdir; ";
		$cmd .= "tar -xzf $tarball" if ($fileType eq "tarGZ");
		$cmd .= "tar -xjf $tarball" if ($fileType eq "tarBZ");
		Utils::Exec::run_cmd ($verboseCfg, $cmd);
	}
	else
	{
		Utils::Fmt::vlogln ($verboseCfg, "$targetDir already exists, not untaring");
	}

	return $targetDir;
}

sub compile_go ($$)
{
	my ($verboseCfg, $ref) = @_;

	return if (!defined ($ref));
	my %go_config = %$ref;

	my $srcDir = $go_config{'srcDir'};
	my $installDir = $go_config{'installDir'};
	my $arch = $go_config{'arch'};

	# Make sure the bootstrap directory created by Go is deleted
	my $cmd = "cd $go_config{'scratch'}; rm -rf go-linux-$arch-bootstrap";
	require "Utils/Exec.pm";
	Utils::Exec::run_cmd ($verboseCfg, $cmd);

	if (defined $go_config{'bootstrapSrcDir'})
	{
		require "Utils/Fmt.pm";
		Utils::Fmt::vlog ($verboseCfg, "Compiling go...");
		my $targetBin = "$srcDir/bin/go";
		if (! -e $targetBin)
		{
			$cmd = "cd $srcDir/src; PATH=$go_config{'bootstrapSrcDir'}/bin:$ENV{'PATH'} ./make.bash";
			Utils::Exec::run_cmd (undef, $cmd);
			Utils::Fmt::vprintln ($verboseCfg, "Success");
		}
		else
		{
			Utils::Fmt::vprintln ($verboseCfg, "$targetBin already exists; skipping compilation");
		}
	}	
	else
	{
		$cmd = "cd $srcDir/src; GOOS=linux GOARCH=$arch ./all.bash";
		Utils::Exec::run_cmd ($verboseCfg, $cmd);
	}
}

sub generic_compile ($$)
{
	my ($verboseCfg, $ref) = @_;
	return if (!defined ($ref));
	my %config = %$ref;

	my $srcDir = $config{'srcDir'};
	my $autogen = "$config{'srcDir'}/autogen.sh";
	my $configure = "$config{'srcDir'}/configure";
	my $makefile = "$config{'srcDir'}/Makefile";

	require "Utils/Exec.pm";
	if (-e $autogen && ! -e $configure && ! -e $makefile)
	{
		my $cmd = "cd $srcDir; ./autogen.sh";
		Utils::Exec::run_cmd ($verboseCfg, $cmd);
	}

	if (-e $configure && ! -e $makefile)
	{
		my $cmd = "cd $srcDir; ./configure";
		Utils::Exec::run_cmd ($verboseCfg, $cmd);
	}

	if (-e "$srcDir/Makefile")
	{
		my $cmd = "cd $srcDir; make";
		Utils::Exec::run_cmd ($verboseCfg, $cmd);
	}
}

sub compile ($$)
{
	my ($verboseCfg, $ref) = @_;

	return if (!defined ($ref));

	my %config = %$ref;

	die "Undefined package" if (!defined($config{'name'}));

	if ($config{'name'} eq "go")
	{
		compile_go ($verboseCfg, $ref);
	}
	else
	{
		generic_compile ($verboseCfg, $ref);
	}
}

# Note: when calling the install() function, make sure to get the configuration back from the
# function as it added very useful information.
sub install ($$)
{
	my ($verboseCfg, $refConfig) = @_;

	return if (!defined (ref));
	my %go_config = %$refConfig;

	require "Utils/Fmt.pm";

	my %hash_test = %$verboseCfg;
	print "Verbosity level: $hash_test{'verbose'}\n";

	Utils::Fmt::vlogln ($verboseCfg, "Install go-bootstrap from $go_config{'bootstrap_url'}");
	Utils::Fmt::vlogln ($verboseCfg, "Install Go from $go_config{'url'}");
	Utils::Fmt::vlogln ($verboseCfg, "Go scratch directory: $go_config{'scratch'}");

	mkdir ($go_config{'installDir'});

	# Deal with Go bootstrap
	my $bootstrapTopDir = "$go_config{'scratch'}/go_bootstrap";
	mkdir ($bootstrapTopDir);
	$go_config{'bootstrapTopDir'} = $bootstrapTopDir;
	$go_config{'bootstrapSrcDir'} = "$go_config{'bootstrapTopDir'}/go-linux-$go_config{'arch'}-bootstrap";

	my %go_bootstrap_config;
	$go_bootstrap_config{'url'} = $go_config{'bootstrap_url'};
	$go_bootstrap_config{'topDir'} = $go_config{'topDir'};
	$go_bootstrap_config{'destdir'} = $go_config{'installDir'};
	$go_bootstrap_config{'scratch'} = "$go_config{'bootstrapTopDir'}";
	$go_bootstrap_config{'arch'} = $go_config{'arch'};
	$go_bootstrap_config{'name'} = "go-bootstrap";
	my ($bootstrap_tarball, $goBootstrapVersion) = download ($verboseCfg, \%go_bootstrap_config);
	$go_bootstrap_config{'tarball'} = $bootstrap_tarball;
	$go_bootstrap_config{'version'} = $goBootstrapVersion;
	untar ($verboseCfg, \%go_bootstrap_config);

	# Deal with Go itself
	# Go does not deal with usual make/make install model so we set a few variables
	# to make sure that we download and compile the Go code in the destination directory.
	$go_config{'destdir'} = $go_config{'installDir'};
	$go_config{'scratch'} = $go_config{'destdir'};

	my ($tarball, $goVersion) = download ($verboseCfg, \%go_config);
	$go_config{'name'} = "go";
	$go_config{'tarball'} = $tarball;
	$go_config{'version'} = $goVersion;
        untar ($verboseCfg, \%go_config);

	my $srcDir = "$go_config{'scratch'}/go";
	$go_config{'srcDir'} = $srcDir;
	Utils::Fmt::vlogln ($verboseCfg, "Compiling Go code from $go_config{'srcDir'} and installing it in $go_config{'installDir'}");
	compile ($verboseCfg, \%go_config);

	## Yes Go expect us to manually copy the binary... yes it is weird... nothing i can do about it.
	#my $cmd = "cp $srcDir/bin/* $go_config{'installDir'};";
	#require "Utils/Exec.pm";
	#Utils::Exec::run_cmd ($verboseCfg, $cmd);

	return %go_config;
}

sub update_modulefile ($$)
{
	my ($verboseCfg, $refConfig) = @_;

	return if (!defined (ref));
	my %config = %$refConfig;

	# sed and perl do not necessarily play well together so we need
	# to do some magic to make sure that we have all the paths
	# properly formatted
	my $installDir = "$config{'installDir'}/go";
	my $modulefile = $config{'modulefile'};
	my $version = $config{'version'};

	# Some sanity checks
	die ("ERROR: Invalid install directory") if (!defined ($installDir) || ! -e $installDir);
	die ("ERROR: Invalid module file") if (!defined ($modulefile) || ! -e $modulefile);
	die ("ERROR: Invalid verison") if (!defined ($version) || $version eq "");

	my $formattedInstallDir = $installDir;
	$formattedInstallDir =~ s/\//\\\//g;

	require "Utils/Exec.pm";

	my $cmd;
	$cmd = "sed -i 's/TOUPDATE_GOINSTALLDIR/$formattedInstallDir/g' $modulefile";
	Utils::Exec::run_cmd (undef, $cmd);

	$cmd = "sed -i 's/TOUPDATE_VERSION/$version/g' $modulefile";
	Utils::Exec::run_cmd (undef, $cmd);
}

sub create_modulefile ($$)
{
	my ($verboseCfg, $refConfig) = @_;

	return if (!defined (ref));
	my %go_config = %$refConfig;
	my $cmd;
	require "Utils/Exec.pm";

	# Firgure out the name of the target file
	die "ERROR: invalid module dir" if (!exists($go_config{'moduledir'}) || !defined ($go_config{'moduledir'}));
	my $go_modulefile_dir = "$go_config{'moduledir'}/golang";
	mkdir ($go_modulefile_dir) if (! -e $go_modulefile_dir);
	my $go_modulefile = "$go_modulefile_dir/$go_config{'version'}";
	$go_config{'modulefile'} = $go_modulefile;

	if (exists($go_config{'force'}) && $go_config{'force'} != 0)
	{
		$cmd = "rm -f $go_modulefile";
		Utils::Exec::run_cmd ($verboseCfg, $cmd);
	}

	require "Utils/Fmt.pm";

	Utils::Fmt::vlog ($verboseCfg, "Creating module file $go_modulefile...");
	if (! -e $go_modulefile) {
		# Copy and update our template
		my $modulefile_template = "$go_config{'topDir'}/etc/modulefile.tmpl";
		$cmd = "cp $modulefile_template $go_modulefile";
		Utils::Exec::run_cmd (undef, $cmd);
		update_modulefile ($verboseCfg, \%go_config);

		Utils::Fmt::vprintln ($verboseCfg, "Success");
	}
	else
	{
		Utils::Fmt::vprintln ($verboseCfg, "$go_modulefile already exists; skipping");
	}
}

1;
