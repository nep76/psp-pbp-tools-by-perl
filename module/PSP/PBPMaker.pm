package PSP::PBPMaker;

# PSP PBP maker module
# Version: 1.0.0
# http://classg.sytes.net

use strict;
use warnings;
use vars qw( $AUTOLOAD );

use File::IOLite;
use PSP::PBPh;

sub new{
	my $class = shift;
	
	my $self = {};
	
	bless( $self, $class );
	
	$self->init;
	$self->{'pbp'} = shift || '';
	
	return $self;
}

sub error{
	return $_[0]->{'error'}->list;
}

sub file{
	$_[0]->{'pbp'} = $_[1] if( $_[1] );
	return $_[0]->{'pbp'};
}

sub init{
	my $self = shift;
	
	%{$self} = (
		pbp   => '',
		pbpfs => {},
		error => Util::ErrorBag->new( 0 )
	);
	
	foreach( PBP_DATA_SEQUENCE ){
		$self->{'pbpfs'}->{$_} = '';
	}
	
	return 1;
}

sub set{
	my $self = shift;
	my $pbpf = shift;
	my $path = shift;
		
	$self->{'error'}->putin("$pbpf is Invalid") if( not exists $self->{'pbpfs'}->{$pbpf} );
	
	$self->{'pbpfs'}->{$pbpf} = $path;
	
	return 1;
}

sub get{
	return $_[0]->{'pbpfs'}->{$_[1]} || undef;
}

sub AUTOLOAD{
	my $self = shift;
	my $path = shift;
	
	my $pbpf = ( split( /::/, $AUTOLOAD ) )[-1];
	
	return $self->set( $pbpf, $path );
}

sub make{
	my $self = shift;
	
	my ( %offset, $len, $prev_offset );
	$prev_offset = 40;
	foreach( PBP_DATA_SEQUENCE ){
		$len = 0;
		
		if( $self->{'pbpfs'}->{$_} ){
			$self->{'error'}->putin("$self->{'pbpfs'}->{$_} is not a file") if( not -f $self->{'pbpfs'}->{$_} );
			$len = (stat($self->{'pbpfs'}->{$_}))[7] || die "$self->{'pbpfs'}->{$_} length 0. Does it not exist or crashed?\n";
		}
		
		$offset{$_} = $prev_offset;
		$prev_offset += $len;
	}
	
	my $Pbp = File::IOLite->new( $self->{'pbp'} );
	$Pbp->open( 'WR', 'FIO_CREATE', 'FIO_APPEND', 'FIO_BLANK' );
	$Pbp->binary;
	$Pbp->write( "\x00PBP" . PBP_VERSION );
	
	$self->{'error'}->putin( "External error:" . $Pbp->error ) if( $Pbp->error );
	
	my ( $cur_ofst, @data );
	foreach( PBP_DATA_SEQUENCE ){
		$cur_ofst = sprintf( '%08x', $offset{$_} );
		$Pbp->write( pack( 'H8', join('', reverse ( unpack( '(A2)*', $cur_ofst ) ) ) ) );
	}
	
	my $File;
	foreach( PBP_DATA_SEQUENCE ){
		next if( not $self->{'pbpfs'}->{$_} );
		$File = File::IOLite->new( $self->{'pbpfs'}->{$_} );
		$File->open( 'RD' );
		$File->binary;
		die "Failed to write: " . $File->error if( $File->error );
		$Pbp->write( $File->read( 1024 ) ) while( not $File->eof );
		$File->close;
	}
	
	$Pbp->close;
}

1;
__END__