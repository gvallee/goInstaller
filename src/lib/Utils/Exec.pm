#
#
#
#
package Utils::Exec;

our @EXPORT_OK = qw(run_cmd);

use lib qw(..);
use Utils::Fmt;

sub run_cmd ($$)
{
	my ($verboseCfg, $cmd) = @_;

	require Utils::Fmt;
	Utils::Fmt::vlogln ($verboseCfg, "Executing: $cmd");
	return system ($cmd);
}

1;
