package AlphaChat::VHost::PublicSuffix;

use strict;
use warnings;
use diagnostics;

our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/LoadList VHostToRHost/;
use Exporter qw/import/;

use AlphaChat::PrintMessage qw/PrintMessage/;

my $suffix_file = "/var/lib/vhost/public_suffix_list.dat";

my $suffix_count = 0;
my $suffix_time = 0;
my $suffixes = +{};

sub LoadList
{
    my $tmp = +{};

    if (open(PSLFILE, "<", $suffix_file))
    {
        my $count = 0;

        while (<PSLFILE>)
        {
            chomp;

            next unless m|^[^ ]+$|;
            next if m|/|;

            $tmp->{$_} = 1;
        }

        close(PSLFILE);

        $count = scalar keys %{$tmp};

        if ($count < 256 || $count < ($suffix_count / 2))
        {
            $@ = sprintf "Failed to load Public Suffix List (TS %d): Too few suffixes", $suffix_time;
            return 0;
        }

        $suffix_count = $count;
        $suffix_time = time();

        $suffixes = +{};
        $suffixes = $tmp;

        PrintMessage "  Loaded Public Suffix List (TS %d): %d entries", $suffix_time, $suffix_count;
        return 1;
    }
    else
    {
        $@ = sprintf "Failed to load Public Suffix List (TS %d): Open failed", $suffix_time;
        return 0;
    }
}

sub VHostToRHost
{
    my ($virtual_host) = @_;

    if ((! $suffix_count) || (time() - $suffix_time) > 86400)
    {
        if (! LoadList() && $suffix_count)
        {
            PrintMessage "  WARN: %s", $@;
        }
        if (! $suffix_count)
        {
            $@ = "Cannot check vHost without a valid Public Suffix List";
            return (0, undef);
        }
    }

    PrintMessage("  Testing existence of entry '%s' ...", $virtual_host);
    return (2, $virtual_host) if exists $suffixes->{$virtual_host};

    my $label;
    my @labels = ('', '');

    while ($virtual_host =~ m|\.|)
    {
        my $prev = $virtual_host;
        ($label, $virtual_host) = split(/\./, $virtual_host, 2);

        shift(@labels) while ($#labels > 1);
        push(@labels, $label);

        PrintMessage("  Testing existence of entry '*.%s' ...", $virtual_host);
        return (2, sprintf('%s.%s', $labels[1], $prev)) if exists $suffixes->{"*.$virtual_host"};

        PrintMessage("  Testing existence of entry '%s' ...", $virtual_host);
        return (2, $prev) if exists $suffixes->{$virtual_host};
    }

    $@ = sprintf "vHost '%s' does not appear on the Mozilla Public Suffix List, no proof necessary", $virtual_host;
    return (1, undef);
}

1;
