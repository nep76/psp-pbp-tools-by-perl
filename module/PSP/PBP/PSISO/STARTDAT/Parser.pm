package PSP::PBP::PSISO::STARTDAT::Parser;

# PSP PSISO STARTDAT parser module
# http://classg.sytes.net

#use strict;
#use warnings;
use vars qw( $VERSION );
use base qw( PSP::PBP::Parser );

$VERSION = "1.0.0";

use File::IOLite;
use PSP::PBP::PSISO::STARTDAT::Const;
use DecHex qw( little_endian_hex2dec );

sub init
{
	my $self = shift;
	
	%{$self} = (
		file      => '',
		total_len => 0,
		len       => {},
		offset    => {},
		error     => Util::ErrorBag->new( 0 )
	
	);
	
	foreach( STARTDAT_STRUCT_SEQ ){
		$self->{'len'}->{$_}    = 0;
		$self->{'offset'}->{$_} = 0
	}
	
	return $self;
}

sub parse{
	my $self = shift;
	
	if( not -f $self->{'file'} ){
		$self->{'error'}->putin( "$self->{'file'} not found" );
		return;
	}
	
	my $STARTDAT = File::IOLite->new( $self->{'file'} );
	$STARTDAT->open( 'RD' );
	
	$self->{'total_len'} = ( stat( $STARTDAT->fh ) )[7];
	
	$STARTDAT->move( 'HEAD', length( STARTDAT_HEADER ) );
	$STARTDAT->move( 'CUR', length( STARTDAT_UNKNOWN_HEADER_DATA ) );
	$self->{'offset'}->{'SPLASH.PNG'} = little_endian_hex2dec( $STARTDAT->read( 4 ) );
	$self->{'len'}->{'SPLASH.PNG'}    = little_endian_hex2dec( $STARTDAT->read( 4 ) );
	$self->{'offset'}->{'PGD'}    = $self->{'offset'}->{'SPLASH.PNG'} + $self->{'len'}->{'SPLASH.PNG'};
	$self->{'len'}->{'PGD'}       = $self->{'total_len'} - $self->{'offset'}->{'PGD'};
	
	return 1;
}

1;