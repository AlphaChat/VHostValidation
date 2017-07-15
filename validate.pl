use strict;
use warnings;
use diagnostics;

use FCGI;
use IO::Handle;
use URI::Query;

use AlphaChat::NameserverLookup qw/NameserverLookup/;
use AlphaChat::PrintMessage qw/PrintMessage SetMessageHandle/;
use AlphaChat::VHost::AuthToken qw/AuthGenerate AuthVerify/;
use AlphaChat::VHost::PublicSuffix qw/LoadList VHostToRHost/;
use AlphaChat::VHost::Validity qw/VHostIsValid/;

LoadList() || die $@;

my $sckpath = "/var/lib/vhost/socket/validator.sock";

my $fd0 = new IO::Handle;
my $fd1 = new IO::Handle;
my $fd2 = new IO::Handle;

my %env = +();
my $sck = FCGI::OpenSocket($sckpath, 10) // die $!;
my $req = FCGI::Request($fd0, $fd1, $fd2, \%env, $sck) // die $!;

chmod 0666, $sckpath;

while ($req->Accept() == 0)
{
    next unless defined $env{'REQUEST_METHOD'};
    next unless defined $env{'QUERY_STRING'};
    next unless $env{'REQUEST_METHOD'} eq 'GET';
    next unless length $env{'QUERY_STRING'};

    my $qry = new URI::Query $env{'QUERY_STRING'};
    my %par = $qry->hash;

    next unless defined $par{'account_name'};
    next unless defined $par{'virtual_host'};
    next unless length $par{'account_name'};
    next unless length $par{'virtual_host'};

    my $account_name = $par{'account_name'};
    my $virtual_host = $par{'virtual_host'};
    my $correct = defined $par{'correct'} ? 1 : 0;

    SetMessageHandle $fd1;

    PrintMessage "Content-Type: text/plain; charset=utf-8\r\n\r\n";

    PrintMessage "Using vHost '%s'", $virtual_host;
    PrintMessage "";

    if (! VHostIsValid($virtual_host))
    {
        PrintMessage "  Invalid vHost: %s", $@;
        next;
    }

    PrintMessage "Matching '%s' against the Public Suffix List ...", $virtual_host;

    $req->Flush();

    my ($result, $hostname) = VHostToRHost $virtual_host;

    if ($result != 2)
    {
        PrintMessage "";
        PrintMessage "  ERROR: %s", $@;
        next;
    }

    PrintMessage "    Found '%s'", $hostname;
    PrintMessage "";
    PrintMessage("Resolving nameservers for '%s' ...", $hostname);

    $req->Flush();

    my @nameservers = NameserverLookup $hostname;

    if (! scalar(@nameservers))
    {
        PrintMessage "";
        PrintMessage "The hostname '%s' does not appear to have any nameservers associated with it!", $hostname;
        PrintMessage "You cannot use this as a vHost!";
        next;
    }

    PrintMessage "";
    PrintMessage "Using account name '%s' (case-sensitive)", $account_name;

    if (! $correct)
    {
        PrintMessage "";
        PrintMessage "Note that the request will only be automatically validated if the information you provided to this script is correct.";
        PrintMessage "For example, the services account name is case-sensitive, and is NOT the same thing as a nickname.";
    }

    my ($prefix, $token) = AuthGenerate($hostname, $account_name);

    PrintMessage "";
    PrintMessage "Please create the following DNS TXT record:";
    PrintMessage "";
    PrintMessage "  Name:     %s.%s", $prefix, $hostname;
    PrintMessage "  Contents: %s", $token;
    PrintMessage "";
    PrintMessage "Once you have created this record, please wait a few moments, and then refresh this webpage";
    PrintMessage "";
    PrintMessage "Checking whether the record is in place now ...";
    PrintMessage "";

    $req->Flush();

    if (AuthVerify($hostname, $account_name, @nameservers))
    {
        PrintMessage "";
        PrintMessage "The record is in place: You may now '/msg HostServ REQUEST %s'", $virtual_host;
    }
    else
    {
        PrintMessage "";
        PrintMessage "The record is not yet in place, do NOT request the vHost yet!";
    }
}
