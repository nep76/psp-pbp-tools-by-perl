package PSP::PBP::PSISO::STARTDAT::Maker;

# PSP PSISO STARTDAT maker modules
# http://classg.sytes.net

#use strict;
#use warnings;
use vars qw( $VERSION );
use base qw( PSP::PBP::Maker );

$VERSION = "1.0.0";

use File::IOLite;
use PSP::PBP::PSISO::STARTDAT::Const;
use DecHex qw( dec2little_endian_hex );

sub BUFFER_SIZE{ 1024 }

sub init
{
	my $self = shift;
	
	%{$self} = (
		file  => '',
		parts => {},
		error     => Util::ErrorBag->new( 0 )
	);
	
	foreach( STARTDAT_STRUCT_SEQ ){
		$self->{'parts'}->{$_} = '';
	}
	
	return $self;
}

sub make{
	my $self = shift;
	
	foreach( STARTDAT_STRUCT_SEQ ){
		if( not -f $self->{'parts'}->{$_} ){
			$self->{'error'}->putin( "$self->{'parts'}->{$_} not found" );
			return;
		}
	}
	
	my $STARTDAT = File::IOLite->new( $self->{'file'} );
	$STARTDAT->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$STARTDAT->binary;
	$STARTDAT->write( STARTDAT_HEADER, STARTDAT_UNKNOWN_HEADER_DATA );
	$STARTDAT->write( dec2little_endian_hex( STARTDAT_HEADER_LENGTH ) );
	$STARTDAT->write( dec2little_endian_hex(  ( stat( $self->{'parts'}->{'SPLASH.PNG'} ) )[7] ) );
	$STARTDAT->write( "\x00" x ( STARTDAT_HEADER_LENGTH() - $STARTDAT->position ) );
	
	my $STARTDATPart;
	foreach( STARTDAT_STRUCT_SEQ ){
		next if( not $self->{'parts'}->{$_} );
		$STARTDATPart = File::IOLite->new( $self->{'parts'}->{$_} );
		$STARTDATPart->open( 'RD' );
		$STARTDATPart->binary;
		$STARTDAT->write( $STARTDATPart->read( BUFFER_SIZE ) ) while( not $STARTDATPart->eof );
		$STARTDATPart->close;
		if( $STARTDATPart->error ){
			$self->{'error'}->putin( "File I/O error: " . $STARTDATPart->error );
			return;
		}
	}
	
	$STARTDAT->close;
	
	if( $STARTDAT->error ){
		$self->{'error'}->putin( $STARTDAT->error );
		return;
	}
	
	return 1;
}

1;