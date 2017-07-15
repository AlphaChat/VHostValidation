package AlphaChat::VHost::Validity;

use strict;
use warnings;
use diagnostics;

our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/VHostIsValid/;
use Exporter qw/import/;

sub VHostIsValid
{
    my ($vhost) = @_;

    if ($vhost !~ m|\.|)
    {
        $@ = "Must contain a period";
        return 0;
    }
    if ($vhost =~ m|^\.| || $vhost =~ m|\.+$|)
    {
        $@ = "Must not begin or end with a period";
        return 0;
    }

    ### XXX TODO This

    return 1;
}

1;
