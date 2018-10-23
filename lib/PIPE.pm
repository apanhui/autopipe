package PIPE;
#-----------------------------------------------+
#    [APM] This moudle was created by amp.pl    |
#    [APM] Created time: 2018-10-22 16:05:58    |
#-----------------------------------------------+
=pod

=head2 v1.0

Date: 2018-10-22 16:05:58

=head1 Name

PIPE -- used to init pipeline

=head1 Synopsis



=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0 beta

Date: 10/22/2018 04:09:47 PM

=cut

use strict;
use warnings;

use File::Path qw/rmtree remove_tree mkpath make_path/;

use FindBin;
use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../";
use lib "$FindBin::RealBin/../lib";

use PIPE::DEBUG;
use PIPE::CONF qw/load_conf/;

#===  FUNCTION  ================================================================
#         NAME: new
#      PURPOSE: create a new object to init a pipeline
#   PARAMETERS: -name, -outdir, -conf_file
#      RETURNS: a 'PIPE' object
#  DESCRIPTION: 
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub new {
	my ($class,%opts) = @_;

	my $pipe = {};
	bless $pipe , $class;

	$pipe->init_pipe();

	return $pipe;
}

sub init_pipe {
	my ($class,%opts) = @_;
	
	# -name
	ERROR("no_pipe_name") unless $opts{'-name'};

	# -outdir
	my $outdir = $opts{'-outdir'} || $opts{'-name'};
	$class->{path}->{outdir} = $outdir;

	# -conf 
	if (ref $opts{'-conf'} eq "HASH"){
		$class->{$conf} = $opts{'-conf'}
	} else {
		$class->{conf} = load_conf($opts{'-conf'});
	}

	## init some public vars 
	$class->{step_id}       = 1;
	$class->{analysis_id}   = 1;
	$class->{path}->{shell} = "$outdir/shell";
	$class->{folders}       = [$outdir];
	$class->{cmd}           = {};
}

sub step {
	my ($class,%opts) = @_;
	my $step = PIPE::STEP->new($class,%opts);
	return $step;
}

sub create_folders {
	my ($class,%opts) = @_;

	rmtree($class->{path}->{outdir}) if ($opts{'-clear'});
	mkpath($class->{folders})
}

sub create_shell {
	my ($class,%opts) = @_;
}
