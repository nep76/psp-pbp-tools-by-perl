package HttpDownloader;

# PSP PBP tools shared module (Downloader)

#use strict;
#use warnings;
use vars qw( $VERSION );

use File::IOLite;
use Util::ErrorBag;

$VERSION = "2.0.0";

sub BUFFER_SIZE     { 1024 }
sub PROTOCOL        { "tcp" }
sub HTTP_PORT       { 80 }
sub HTTP_METHOD     { "GET" }
sub HTTP_VERSION    { "HTTP/1.0" }
sub HTTP_USER_AGENT { "PSP PBP editor $VERSION (http://classg.sytes.net)" }

sub new
{
	my $class = shift;
	my $self  = {};
	
	bless( $self, $class );
	
	$self->init;
	return $self;
}

sub init
{
	my $self = shift;
	
	%{$self} = (
		http_sock => undef,
		host      => '',
		port      => HTTP_PORT,
		http_ua   => HTTP_USER_AGENT,
		error     => Util::ErrorBag->new( 0 )
	);
	
	return 1;
}

sub error
{
	return $_[0]->{'error'}->list;
}

sub set_http_uri
{
	my $self = shift;
	my $uri  = shift;
	
	my ( $proto, $host, $port, $path );
	if( $uri =~ /:/ ){
		( $proto, $uri ) = split( /:\/\//, $uri );
	} else{
		$proto = 'http';
	}
	
	if( $proto ne 'http' ){
		$self->{'error'}->putin( "Protocol \"$proto\" not suportted" );
		return;
	}
	
	( $host,  $path ) = split( /\//, $uri , 2 );
	( $host,  $port ) = split( /:/ , $host, 2 );
	
	$self->{'host'} = $host;
	$self->{'path'} = $path;
	$self->{'port'} = $port if( $port );
	
	return 1;
}

sub host
{
	$_[0]->{'host'} = $_[1] if( $_[1] );
	return $_[0]->{'host'};
}

sub path
{
	$_[0]->{'path'} = $_[1] if( $_[1] );
	return $_[0]->{'path'};
}

sub port
{
	$_[0]->{'port'} = $_[1] if( $_[1] );
	return $_[0]->{'port'};
}

sub http_user_agent
{
	$_[0]->{'http_ua'} = $_[1] if( $_[1] );
	return $_[0]->{'http_ua'};
}

sub connect_to_server
{
	my $self = shift;
	
	$self->{'http_sock'} = IO::Socket::INET->new(
		PeerAddr => $self->{'host'},
		PeerPort => $self->{'port'},
		Proto    => PROTOCOL
	);
	
	if( not ref $self->{'http_sock'} ){
		$self->{'error'}->putin( "Cannot connect to server $self->{'host'}:$self->{'port'}" );
		return;
	}
	
	binmode( $self->{'http_sock'} );
	
	return 1;
}

sub _http_req{ print {$_[0]} join( '', $_[1], "\x0D\x0A" );  }

sub send_http_request
{
	my $self = shift;
	
	if( not ref $self->{'http_sock'} ){
		$self->{'error'}->putin( "At first, connecto to server" );
		return;
	}
	
	_http_req( $self->{'http_sock'}, HTTP_METHOD . " /$self->{'path'} " . HTTP_VERSION );
	_http_req( $self->{'http_sock'}, "Host: $self->{'host'}" );
	_http_req( $self->{'http_sock'}, "User-Agent: " . $self->{'http_ua'} );
	_http_req( $self->{'http_sock'}, "Connection: close" );
	
	_http_req( $self->{'http_sock'}, "" );
	
	$self->{'http_sock'}->flush;
}

sub download
{
	my $self     = shift;
	my $savepath = shift;
	
	if( not ref $self->{'http_sock'} ){
		$self->{'error'}->putin( "At first, connecto to server" );
		return;
	}
	
	my $http_status = substr( readline( $self->{'http_sock'} ), 9, 3 );
	
	if( $http_status != 200 ){
		$self->{'error'}->putin( "HTTP access is not successful. Status $http_status " );
		return;
	}
	
	1 while( readline( $self->{'http_sock'} ) ne "\x0D\x0A" );
	
	my $Tempfile = File::IOLite->new( $savepath );
	$Tempfile->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$Tempfile->binary;
	
	my $buf;
	while( not eof $self->{'http_sock'} ){
		if( $Tempfile->error ){
			$self->{'error'}->putin( $Tempfile->error );
			return;
		}
		read( $self->{'http_sock'}, $buf, BUFFER_SIZE );
		$Tempfile->write( $buf );
	}
	
	$Tempfile->close;
	
	if( $Tempfile->error ){
		$self->{'error'}->putin( $Tempfile->error );
		return;
	}
	
	return 1;
}

sub disconnect
{
	my $self = shift;
	
	if( not ref $self->{'http_sock'} ){
		$self->{'error'}->putin( "At first, connecto to server" );
		return;
	}
	
	$self->{'http_sock'}->close;
	
	return 1;
}

1;