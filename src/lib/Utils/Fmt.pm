#
# Copyright(c)		2019	UT-Battelle, LLC
#				All rights reserved
#

package Utils::Fmt;

our @EXPORT_OK = qw(set_verbosity
		vprint
		vlog
		vlogln);

sub set_verbosity ($$)
{
	my ($ref, $v) = @_;

	if (defined ($ref))
	{
		my %config = %$ref;
		$config{'verbose'} = $v;
		return \%config
	}

	return undef;
}

sub vprintln ($$)
{
	my ($ref, $msg) = @_;

	return if (!defined ($ref));

	my %cfg = %$ref;
	print "$msg\n" if ($cfg{'verbose'});
}

sub vprint ($$)
{
	my ($ref, $msg) = @_;

	return if (!defined ($ref));

	my %cfg = %$ref;
	print "$msg " if ($cfg{'verbose'});
}

sub vlogln ($$)
{
        my ($ref, $msg) = @_;

        return if (!defined ($ref));

        my %cfg = %$ref;
        print "* $msg\n" if ($cfg{'verbose'});
}

sub vlog ($$)
{
        my ($ref, $msg) = @_;

        return if (!defined ($ref));

        my %cfg = %$ref;
        print "* $msg " if ($cfg{'verbose'});
}


1;
