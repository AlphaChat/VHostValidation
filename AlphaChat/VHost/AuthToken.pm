package AlphaChat::VHost::AuthToken;

use strict;
use warnings;
use diagnostics;

our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/AuthGenerate AuthVerify/;
use Exporter qw/import/;

use Digest::SHA qw/sha256 sha256_hex hmac_sha256_base64/;
use Net::DNS;

use AlphaChat::PrintMessage qw/PrintMessage/;

sub AuthGenerate
{
    my ($hostname, $account) = @_;

    my $prefix = "hsvd-" . substr(sha256_hex($account), 0, 16);
    my $token = hmac_sha256_base64($hostname, sha256($account));

    return ($prefix, $token);
}

sub AuthVerify
{
    my ($hostname, $account, @nameservers) = @_;

    my ($prefix, $token) = AuthGenerate $hostname, $account;
    my $resolver = new Net::DNS::Resolver('retrans' => 3, 'retry' => 2, 'tcp_timeout' => 5, 'udp_timeout' => 5);

    $hostname = sprintf "%s.%s", $prefix, $hostname;

    foreach my $nameserver (@nameservers)
    {
        PrintMessage "  Running query for '%s' against '%s' ...", $hostname, $nameserver;

        $resolver->nameservers($nameserver);

        if (my $packet = $resolver->send($hostname, "TXT", "IN"))
        {
            foreach my $answer ($packet->answer)
            {
                next unless $answer->type eq "TXT";

                foreach my $contents ($answer->txtdata)
                {
                    if ($contents eq $token)
                    {
                        PrintMessage "      Match!";
                        return 1;
                    }
                }
            }
        }

        PrintMessage "    No match";
    }

    return 0;
}

1;
