package AlphaChat::NameserverLookup;

use strict;
use warnings;
use diagnostics;

our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/NameserverLookup/;
use Exporter qw/import/;

use Net::DNS;

use AlphaChat::PrintMessage qw/PrintMessage/;

sub NameserverLookup
{
    my ($hostname) = @_;

    my $resolver = new Net::DNS::Resolver('retrans' => 3, 'retry' => 2, 'tcp_timeout' => 5, 'udp_timeout' => 5);
    my %answers = +();

    if (my $packet = $resolver->send($hostname, 'SOA', 'IN'))
    {
        foreach my $answer (($packet->answer), ($packet->authority), ($packet->additional))
        {
            next unless $answer->type eq 'SOA';
            next unless $answer->name =~ m|\.|;
            next unless $answer->mname =~ m|\.|;

            my $result = lc $answer->mname;
            PrintMessage "  Found nameserver '%s' (SOA MNAME)", $result;
            $answers{$result} = 1;
        }
    }

    if (my $packet = $resolver->send($hostname, 'NS', 'IN'))
    {
        foreach my $answer (($packet->answer), ($packet->authority), ($packet->additional))
        {
            next unless $answer->type eq 'NS';
            next unless $answer->name =~ m|\.|;
            next unless $answer->nsdname =~ m|\.|;

            my $result = lc $answer->nsdname;
            PrintMessage "  Found nameserver '%s' (NS DNAME)", $result;
            $answers{$result} = 1;
        }
    }

    return keys %answers;
}

1;
