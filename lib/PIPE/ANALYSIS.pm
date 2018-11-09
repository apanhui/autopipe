package PIPE::ANALYSIS;
#-----------------------------------------------+
#    [APM] This moudle was created by amp.pl    |
#    [APM] Created time: 2018-10-23 12:01:34    |
#-----------------------------------------------+
=pod

=head1 Name

ANALYSIS

=head1 Synopsis



=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0

Date: 2018-10-23 12:01:34

=cut


use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);

use FindBin;
use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../";
use lib "$FindBin::RealBin/../lib";

use PIPE::DEBUG;

sub new {
	my ($class,$parent,$step,%opts) = @_;

	my $analysis = {parent=>$parent,step=>$step};
	bless $analysis , $class;

	$analysis->init_analysis(%opts);

	return $analysis;
}

sub init_analysis {
	my ($class,%opts) = @_;
	
	ERROR('no_analysis_name') unless $opts{'-name'};
	$class->{name} = $opts{'-name'};
	$class->{id}   = $class->{step}->{id} . "." . $class->{parent}->{analysis_id};
	$class->{cmd}  = "";
	
	$class->{path} = "$class->{step}->{path}/$class->{id}.$class->{name}";
	
	# define the resource of jobs 
	$class->{mem}     = $opts{'-mem'}     || "1G";
	$class->{cpu}     = $opts{'-cpu'}     || 1; # the maximum job number
	$class->{threads} = $opts{'-threads'} || 1; # the threads of each job
	$class->{queue}   = $opts{'-queue'}   || "all.q";

	$class->{parent}->{analysis_id} ++;
}

#===  FUNCTION  ================================================================
##         NAME: cmd
##      PURPOSE: paste cmd 
##   PARAMETERS: --nobar: paste cmd with no newline
##      RETURNS: null
##===============================================================================
sub cmd {
	my ($class,$cmd,%opts) = @_;

	$class->{cmd} .= $cmd;
	$class->{cmd} .= "\n" unless $opts{'-nobr'};
}
