package PSP::PBP::Parser;

#use strict;
#use warnings;
use vars qw( $VERSION );

use File::IOLite;
use Util::ErrorBag;
use PSP::PBP::Const;
use DecHex qw( little_endian_hex2dec );
	
$VERSION = "2.0.0";

sub BUFFER_SIZE{ 1024 }

sub new
{
	my $class = shift;
	my $self  = {};
	
	bless( $self, $class );
	
	$self->init;
	$self->file( shift );
	
	return $self;
}

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
	
	foreach( PBP_STRUCT_SEQ ){
		$self->{'len'}->{$_}    = 0;
		$self->{'offset'}->{$_} = 0;
	}
	
	return $self;
}

sub error
{
	return $_[0]->{'error'}->list;
}

sub file
{
	$_[0]->{'file'} = $_[1] if( $_[1] );
	return $_[0]->{'file'};
}

sub parse{
	my $self = shift;
	
	if( not -f $self->{'file'} ){
		$self->{'error'}->putin( "$self->{'file'} not found" );
		return;
	}
	
	my $PBP = File::IOLite->new( $self->{'file'} );
	$PBP->open( 'RD' );
	$PBP->binary;
	
	$self->{'total_len'} = ( stat( $PBP->fh ) )[7];
	
	if( $PBP->read( PBP_HEADER_FIELD_LENGTH ) ne PBP_HEADER ){
		$self->{'error'}->putin( "$self->{'file'} is not valid PBP header" );
		return;
	}
	
	$PBP->move( 'CUR', PBP_HEADER_FIELD_LENGTH );
	
	foreach( PBP_STRUCT_SEQ ){
		$self->{'offset'}->{$_} = little_endian_hex2dec( $PBP->read( PBP_HEADER_FIELD_LENGTH ) );
	}
	
	my ( $prev_len, $prev_offset ) = ( 0, 0 );
	foreach( reverse PBP_STRUCT_SEQ ){
		$self->{'len'}->{$_} = $self->{'total_len'} - ( $self->{'offset'}->{$_} + $prev_len );
		
		if( $self->{'offset'}->{$_} == $prev_offset ){
			$self->{'len'}->{$_}    = 0;
			$self->{'offset'}->{$_} = 0;
		} else{
			$prev_len    += $self->{'len'}->{$_};
			$prev_offset = $self->{'offset'}->{$_};
		}
	}
	
	$PBP->close;
	
	return 1;
}

sub total_len
{
	return $_[0]->{'total_len'};
}

sub len
{
	return ( defined $_[1] ? $_[0]->{'len'}->{$_[1]} : undef );
}

sub offset
{
	return ( defined $_[1] ? $_[0]->{'offset'}->{$_[1]} : undef );
}

sub fdump
{
	my $self = shift;
	my $part = shift;
	my $path = shift;
	
	my $loop = 0;
	my $frac = 0;
	
	if( not exists $self->{'len'}->{$part} ){
		$self->{'error'}->putin( "Unknown structure file name: $part" );
		return;
	} elsif( not $self->{'len'}->{$part} ){
		return 1;
	} elsif( $self->{'len'}->{$part} < BUFFER_SIZE ){
		$loop = 0;
		$frac = $self->{'len'}->{$part};
	} else{
		$loop = int( $self->{'len'}->{$part} / BUFFER_SIZE );
		$frac = $self->{'len'}->{$part} - ( BUFFER_SIZE() * $loop );
	}
	
	my ( $PBP, $PBPPart );
	$PBP = File::IOLite->new( $self->{'file'} );
	$PBP->open( 'RD' );
	$PBP->binary;
	$PBP->move( 'HEAD', $self->{'offset'}->{$part} );
	
	$PBPPart = File::IOLite->new( $path );
	$PBPPart->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$PBPPart->binary;
	
	if( $PBP->error ){
		$self->{'error'}->putin( $PBP->error );
		return;
	}
	
	if( $PBPPart->error ){
		$self->{'error'}->putin( $PBPPart->error );
		return;
	}
	
	$PBPPart->write( $PBP->read( BUFFER_SIZE ) ) while( $loop-- );
	$PBPPart->write( $PBP->read( $frac )       ) if( $frac );
	
	$PBPPart->close;
	$PBP->close;
	
	if( $PBP->error ){
		$self->{'error'}->putin( $PBP->error );
		return;
	}
	
	if( $PBPPart->error ){
		$self->{'error'}->putin( $PBPPart->error );
		return;
	}
	
	return 1;
}

1;