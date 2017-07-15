package AlphaChat::VHost::Validity;

use strict;
use warnings;
use diagnostics;

our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/AccountNameIsValid VHostIsValid/;
use Exporter qw/import/;

sub AccountNameIsValid
{
    my ($account) = @_;

    if ($account =~ m|[^A-Z0-9\[\]\{\}\^\`\_\-\\\|]|in)
    {
        $@ = "Contains invalid characters";
        return 0;
    }

    return 1;
}

sub VHostIsValid
{
    my ($vhost) = @_;
    my $label;

    if ($vhost !~ m|\.|)
    {
        $@ = "Does not contain a period";
        return 0;
    }
    if ($vhost =~ m|\.\.|)
    {
        $@ = "Contains 2 or more consecutive periods";
        return 0;
    }
    if ($vhost =~ m|^\.| || $vhost =~ m|\.+$|)
    {
        $@ = "Contains a period at the beginning or end";
        return 0;
    }
    if ($vhost =~ m|[^A-Z0-9.-]|in)
    {
        $@ = "Contains invalid characters";
        return 0;
    }
    while ($vhost =~ m|\.|)
    {
        ($label, $vhost) = split(/\./, $vhost, 2);

        if ($label =~ m|^-| || $label =~ m|-$|)
        {
            $@ = "Contains a label that starts or ends with a hyphen";
            return 0;
        }
    }

    return 1;
}

1;
