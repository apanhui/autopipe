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
our @EXPORT    = qw(md_cmd md_context );
our @EXPORT_OK = qw( md_cmd md_context );

sub md_cmd {
    my $object = shift;
    return "" unless $object->{cmd};
    
    chomp $object->{cmd};
    return "\n```bash\n$object->{cmd}\n```\n";
}

sub md_context {
    my $object = shift;
    my $layer = @_ ? shift : 
                ref $object eq "PIPE"           ? 2 : 
                ref $object eq "PIPE::STEP"     ? 3 : 
                ref $object eq "PIPE::ANALYSIS" ? 4 : 5;
    
    my $sharps = '#' x $layer;
    my $md = "";
    if ($layer <= 2){
        my $prjid = $object->{conf}->{project_id} || "NA";
        $md = <<MD;
[TOC]

$sharps Pipeline: $object->{pipe_name}

+ Project ID: **$prjid**
+ Created User: **$ENV{USER}**
+ Created Time: **`$object->{ctime}`**
+ Finished Time: **`$object->{ftime}`**
+ Work dir: **`$object->{path}`**
+ Total shell file: **`$object->{shelldir}/all_steps.sh`**
MD
    } else {
        $md = <<MD;

$sharps $object->{id}.$object->{name}

+ Created time: **`$object->{ctime}`**
+ Finished time: **`$object->{ftime}`**
+ Work dir: **`$object->{path}`**
+ Shell file: **`$object->{parent}->{shelldir}/SH$object->{id}.$object->{name}.sh`**
+ CPUs: **$object->{cpu}**
+ Queue: **$object->{queue}**
+ Memory: **$object->{mem}**
MD
    }

    return $md;
}
