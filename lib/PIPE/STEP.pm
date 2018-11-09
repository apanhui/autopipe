package PIPE::STEP;
#-----------------------------------------------+
#    [APM] This moudle was created by amp.pl    |
#    [APM] Created time: 2018-10-22 16:42:30    |
#-----------------------------------------------+
=pod

=head1 Name

STEP

=head1 Synopsis



=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0

Date: 2018-10-22 16:42:30

=cut

use strict;
use warnings;

require Exporter;
our @ISA       = qw(Exporter);

use File::Basename qw/dirname basename/;

use FindBin;
use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../";
use lib "$FindBin::RealBin/../lib";

use PIPE::DEBUG;
use PIPE::ANALYSIS;

sub new {
	my ($class,$parent,%opts) = @_;
	
	my $step = {parent=>$parent};
	bless $step , $class;
	$step->init_step(%opts);
	
	return $step;
}

sub init_step {
	my ($class,%opts) = @_;
	
	ERROR('no_step_name') unless $opts{'-name'};
	
	# init some attributes of step 
	$class->{name} = $opts{'-name'};
	$class->{id}   = $class->{parent}->{step_id};
	$class->{cmd}  = "";
	$class->{path} = "$class->{parent}->{path}/$class->{id}.$class->{name}";
	
	# define the resource of jobs 
	$class->{mem}     = $opts{'-mem'}     || "1G";
	$class->{cpu}     = $opts{'-cpu'}     || 1; # the maximum job number
	$class->{threads} = $opts{'-threads'} || 1; # the threads of each job
	$class->{queue}   = $opts{'-queue'}   || "all.q";
	
	$class->{analysis} = {};

	$class->{parent}->{analysis_id} = 1;
	$class->{parent}->{step_id} ++;
}

sub analysis {
	my ($class,%opts) = @_;
	my $analysis = PIPE::ANALYSIS->new($class->{parent},$class,%opts);
	$class->{analysis}->{$analysis->{id}} = $analysis;
	$class->{shelldir} = "$class->{parent}->{shelldir}/$class->{id}.$class->{name}" unless $class->{shelldir};
	return $analysis;
}

*substep = \&analysis;

#===  FUNCTION  ================================================================
#         NAME: cmd
#      PURPOSE: paste cmd 
#   PARAMETERS: --nobar: paste cmd with no newline
#      RETURNS: null
#===============================================================================
sub cmd {
	my ($class,$cmd,%opts) = @_;

	$class->{cmd} .= $cmd;
	$class->{cmd} .= "\n" unless $opts{'-nobr'};
}

sub all_analysis {
	my ($class,%opts) = @_;
	my @analysis = map { $class->{analysis}->{$_} } sort {$a<=>$b} keys %{$class->{analysis}};
	return @analysis;
}
