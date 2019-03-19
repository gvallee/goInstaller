#
# Copyright(c)		2019	UT-Battelle, LLC
#				All rights reserved.
#

package Utils::ConfParser;

our @EXPORT_OK = qw(
		print_config
		loaf_config
		);

sub print_config ($)
{
        my ($ref) = @_; 

        return if (!defined ($ref));
        my %config = %$ref;
        foreach my $k (keys (%config))
        {   
                print ("-> $k: $config{$k}\n");
        }   
}

sub load_config ($)
{
        my ($configfile) = @_; 

        # Sanity check
        return undef if (!defined ($configfile) || ! -e $configfile);

        my %config;

        open (my $fh, '<', $configfile) or die "ERROR: Cannot open $configfile";
        my @lines = <$fh>;
        close ($fh);

        my $cur_block = undef;
        foreach my $line (@lines)
        {   
                next if ($line =~ /^[ \t]*#/); # We skip comments

                if ($line =~ /^[ \t]*\[(.*)\]/)
                {   
                        # Block header
                        $cur_block = $1; 
                }   

                if ($line =~ /(.*) = (.*)/ || $line =~ /(.*)=(.*)/)
                {   
                        my $key = $1; 
                        my $value = $2; 
                        $key = $cur_block . "_$key" if (defined ($cur_block));

                        $config{$key} = $value;
                }   
        }   

        return \%config;
}

1;
