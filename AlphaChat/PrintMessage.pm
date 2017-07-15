package AlphaChat::PrintMessage;

use strict;
use warnings;
use diagnostics;

our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/PrintMessage SetMessageHandle SetMessageNewLine/;
use Exporter qw/import/;

my $handle = undef;
my $newline = 1;

sub PrintMessage
{
    if (defined $handle)
    {
        printf { $handle } @_;
        print { $handle } "\n" if $newline;
    }
    else
    {
        printf @_;
        print "\n" if $newline;
    }
}

sub SetMessageHandle
{
    my ($p_handle) = @_;

    $handle = $p_handle;
}

sub SetMessageNewLine
{
    my ($p_newline) = @_;

    $newline = $p_newline;
}

1;
