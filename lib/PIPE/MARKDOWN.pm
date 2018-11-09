package PIPE::MARKDOWN;
#-----------------------------------------------+
#    [APM] This moudle was created by amp.pl    |
#    [APM] Created time: 2018-11-09 09:52:49    |
#-----------------------------------------------+
=pod

=head1 Name

MARKDOWN

=head1 Synopsis



=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0

Date: 2018-11-09 09:52:49

=cut


use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT    = qw(md_cmd );
our @EXPORT_OK = qw( md_cmd );

use FindBin;
use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../";
use lib "$FindBin::RealBin/../lib";

sub md_cmd {
    my $object = shift;
    return "" unless $object->{cmd};
    
    chomp $object->{cmd};
    return "\n```bash\n$object->{cmd}\n```\n";
}
