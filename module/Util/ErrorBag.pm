package Util::ErrorBag;

#use strict;
#use utf8;
use vars qw($VERSION);
$VERSION = 1.0.0;

sub new{
	my $class = shift;
	
	my $self = {
		errors  => [],
		verbose => shift || 0
	};
	
	bless($self, $class);
}#END new

sub putin{
	my $class = shift;
	my $value = shift | '';
	my $sader = shift || 0;
	my $backstack = 1;
	
	if( $sader =~ /[0-9]+/ ){
		$backstack += $sader;
		$sader = (split('::',(caller($backstack))[3]))[-1]
	}
	
	if( $class->{'verbose'} ){
		my ($filename, $line) = (caller($backstack))[1,2];
		$value .= " at $filename line $line";
	}
	
	if( $value =~ /\n/ ){
		$value =~ s/\n/\n \| /g;
		$value = " | " . $value;
	} else{
		$value .= '.';
	}
	
	push(@{$class->{'errors'}}, qq($sader Error: $value));
	
	return 1;
}#END putin

sub pickup{
	my $class = shift;
	my $arg   = shift;
	
	return scalar(@{$class->{'errors'}}) if( ! defined($arg) );
	
	return ${$class->{'errors'}}[$arg] || undef;
}#END pickup

sub list{
	my $class = shift;
	
	return join("\n", @{$class->{'errors'}}) || undef;
}#END list

sub exhaust{
	my $class = shift;
	
	$class->{'errors'} = [];
	
	return 1;
}#END exhaust

1;
__END__