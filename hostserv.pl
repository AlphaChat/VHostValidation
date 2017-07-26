use strict;
use warnings;
use diagnostics;

use Irssi;
use Irssi::Irc;

use AlphaChat::NameserverLookup qw/NameserverLookup/;
use AlphaChat::PrintMessage qw/PrintMessage SetMessageNewLine/;
use AlphaChat::VHost::AuthToken qw/AuthVerify/;
use AlphaChat::VHost::PublicSuffix qw/LoadList VHostToRHost/;
use AlphaChat::VHost::Validity qw/VHostIsValid/;

my $recent_sec = 86400;
my $uri_prefix = 'https://validation.alphachat.net/cgi-bin/validate.pl';
my $chatnet    = 'AlphaChat';
my $hsnick     = 'HostServ';
my $nsnick     = 'NickServ';
my $hchan      = '#help';
my $ochan      = '#opers';
my $schan      = '#services';

my %activated  = +();

sub SendChannelMessage
{
    my ($server, $format, @argv) = @_;
    my $message = sprintf($format, @argv);

    PrintMessage "--> [%s] %s", $ochan, $message;

    $server->send_message($ochan, $message, 0);
}

sub SendPrivateMessage
{
    my ($server, $target, $format, @argv) = @_;
    my $message = sprintf($format, @argv);

    PrintMessage "--> [%s] %s", $target, $message;

    $server->send_message($target, $message, 1);
}

sub VHostRecentlyActivated
{
    my ($account_name) = @_;

    return 0 unless exists $activated{$account_name};
    return 1 if ((time() - $activated{$account_name}) < $recent_sec);

    delete $activated{$account_name};
    return 0;
}

sub VHostRecordAccountChange
{
    my ($server, $old_name, $new_name) = @_;

    return unless exists $activated{$old_name};

    if ((time() - $activated{$old_name}) >= $recent_sec)
    {
        delete $activated{$old_name};
        return;
    }
    if (exists($activated{$new_name}) && (time() - $activated{$new_name}) < $recent_sec)
    {
        SendChannelMessage $server, "WARN: Account '%s' overwriting earlier account '%s' vHost activation timestamp", $old_name, $new_name;
    }

    $activated{$new_name} = $activated{$old_name};
    delete $activated{$old_name};
}

sub VHostRecordActivation
{
    my ($account_name) = @_;

    $activated{$account_name} = time();
}

sub VHostActivate
{
    my ($server, $account_name) = @_;

    PrintMessage "  Activating vHost request for '%s' ...", $account_name;

    SendPrivateMessage $server, $hsnick, "ACTIVATE %s", $account_name;
    VHostRecordActivation $account_name;
}

sub VHostReject
{
    my ($server, $account_name, $host, $reason) = @_;

    PrintMessage "  Rejecting vHost request for '%s' (%s) ...", $account_name, $reason;

    SendPrivateMessage $server, $hsnick, "REJECT %s Unacceptable vHost/Suffix '%s' (%s)", $account_name, $host, $reason;
}

sub VHostHandleRequest
{
    my ($server, $nick, $account_name, $virtual_host) = @_;

    PrintMessage "";
    PrintMessage "<-- The account '%s' has requested vHost '%s'", $account_name, $virtual_host;

    if (! VHostIsValid($virtual_host))
    {
        VHostReject $server, $account_name, $virtual_host, $@;
        return;
    }
    if (VHostRecentlyActivated($account_name))
    {
        VHostReject $server, $account_name, $virtual_host, "you have already had a vHost activated recently";
        return;
    }

    PrintMessage "Matching '%s' against the Public Suffix List ...", $virtual_host;

    my ($result, $hostname) = VHostToRHost $virtual_host;

    if ($result == 0)
    {
        SendChannelMessage $server, "WARN: unusable Public Suffix List, cannot check request '%s'!", $virtual_host;
        return;
    }
    if ($result == 1)
    {
        SendChannelMessage $server, "INFO: requested vHost '%s' does not match the Public Suffix List, consider activating it", $virtual_host;
        return;
    }
    if ($result != 2)
    {
        SendChannelMessage $server, "CRIT: VHostToRHost BUG: result code is not 0, 1, or 2!";
        return;
    }

    PrintMessage "    Found '%s'", $hostname;
    PrintMessage "Resolving nameservers for '%s' ...", $hostname;

    my @nameservers = NameserverLookup $hostname;

    if (! scalar(@nameservers))
    {
        VHostReject $server, $account_name, $virtual_host, "does not appear to have any nameservers associated with it";
        return;
    }
    if (AuthVerify($hostname, $account_name, @nameservers))
    {
        VHostActivate $server, $account_name;
        return;
    }

    my $message1 = "[Automatic Message] You are receiving these messages because you requested a vHost.";
    my $message2 = "To request the vHost '%s', please visit %s?virtual_host=%s&account_name=%s&correct";

    my $message3 = "Alternatively, join the '%s' channel to manually prove that you have " .
                   "control over the domain '%s'. This will take longer, as a human has to " .
                   "review the request, confirm your proof, and manually assign your vHost.";

    my $message4 = "Do not reply to these messages; no-one monitors this bot for responses.";

    SendPrivateMessage $server, $nick, $message1;
    SendPrivateMessage $server, $nick, $message2, $virtual_host, $uri_prefix, $virtual_host, $account_name;
    SendPrivateMessage $server, $nick, $message3, $hchan, $hostname;
    SendPrivateMessage $server, $nick, $message4;

    VHostReject $server, $account_name, $hostname, "missing or invalid DNS TXT record";
}

Irssi::signal_add_first("message public", sub {

    my ($server, $message, $nick, undef, $channel) = @_;

    return unless ($server->{"chatnet"} eq $chatnet);
    return unless ($channel eq $schan);

    $message =~ s|\002||g;

    if ($nick eq $hsnick && $message =~ m|^[^ ]+ ACTIVATE: [^ ]+ for ([^ ]+)$|)
    {
        VHostRecordActivation $1;
        Irssi::signal_stop();
    }
    elsif ($nick eq $hsnick && $message =~ m|^([^ ]+) REQUEST: ([^ ]+)$|)
    {
        VHostHandleRequest $server, $1, $1, $2;
        Irssi::signal_stop();
    }
    elsif ($nick eq $hsnick && $message =~ m|^([^ ]+) \(([^ ]+)\) REQUEST: ([^ ]+)$|)
    {
        VHostHandleRequest $server, $1, $2, $3;
        Irssi::signal_stop();
    }
    elsif ($nick eq $nsnick && $message =~ m|^([^ ]+) SET:ACCOUNTNAME: ([^ ]+)$|)
    {
        VHostRecordAccountChange $server, $1, $2;
        Irssi::signal_stop();
    }
    elsif ($nick eq $nsnick && $message =~ m|^[^ ]+ \(([^ ]+)\) SET:ACCOUNTNAME: ([^ ]+)$|)
    {
        VHostRecordAccountChange $server, $1, $2;
        Irssi::signal_stop();
    }

});

SetMessageNewLine 0;

LoadList() || die $@;
