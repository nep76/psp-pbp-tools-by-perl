#!/usr/local/bin/perl

# PSP PBP editor by Perl
# http://classg.sytes.net

use strict;
use warnings;
use vars qw( $VERSION @g_tmpfiles );

BEGIN{
	my $self = $0;
	$self =~ s/\\/\//g;
	if( $self =~ /\// ){
		$self = substr( $self, 0, rindex( $self, '/' ) );
	} else{
		$self = '.' ;
	}
	push( @INC, "$self/module" );
}

use IO::Socket;
use File::IOLite;

use PSP::PBPh;
use PSP::PBPParser;
use PSP::PBPMaker;

$VERSION = "1.2.1";

sub LIST   { 'LIST' }
sub CREATE { 'CREATE' }
sub REWRITE{ 'REWRITE' }
sub EXTRACT{ 'EXTRACT' }

sub BUFFER_SIZE     { 1024 }
sub PROTOCOL        { "tcp" }
sub HTTP_PORT       { 80 }
sub HTTP_METHOD     { "GET" }
sub HTTP_VERSION    { "HTTP/1.0" }
sub HTTP_USER_AGENT { "PSP PBP editor $VERSION (http://classg.sytes.net)" }

if   ( not defined $ARGV[0] ){ usage(); }
elsif( scalar( @ARGV ) < 1 ) { error("Not enought arguments"); }

my $ope      = shift @ARGV || '';
$ope = uc( $ope );

switch:{
	
	( $ope eq LIST    ) and do{ list   ( @ARGV ); last; };
	( $ope eq CREATE  ) and do{ create ( @ARGV ); last; };
	( $ope eq REWRITE ) and do{ rewrite( @ARGV ); last; };
	( $ope eq EXTRACT ) and do{ extract( @ARGV ); last; };
	
	usage();
}

#------------------------------------------------
sub error{
	my $err = shift;
	$err =~ s/_VAR_/shift/eg if( scalar( @_ ) );
	die "Error: $err" . ".\n";
}

sub usage{
	die <<_USAGE_;
PSP PBP editor by Perl.

Usage: perl ppe.pl [operation] Target_PBP_File
    
    operation:
      list            Displaying files list in the Target_PBP_File.
      help | -h       Displaying help document. (It is this)
      extract CONTROL Extract the Target_PBP_File to CONTROL's PATH directory.
      create CONTROL  Create new PBP file.
                      (In this case, Target_PBP_File is new PBP file name.
                       So, -o option will ignore.)
      rewrite CONTROL Replace (or insert) some files in the Target_PBP_File.

    CONTROL:
      -p PATH | HTTP-URI    PARAM.SFO.
                            This is PBP metadata file.
      -m PATH | HTTP-URI    CON0.PNG.
                            This is main icon image.
      -a PATH | HTTP-URI    ICON1.PMF.
                            This is animation icon file.
      -f PATH | HTTP-URI    PIC0.PNG.
                            This is floating image on the background image.
                            (This is overlaid on the PIC1.PNG)
      -b PATH | HTTP-URI    PIC1.PNG.
                            This is background image.
      -s PATH | HTTP-URI    SND0.AT3.
                            This is background music.
      -0 PATH | HTTP-URI    DATA.PSP.
      -1 PATH | HTTP-URI    DATA.PSAR.

      (If you set PATH to "none" then it will remove from the Target_PBP_File.)
      
      for "rewrite" and "extract" operation:
      -o PATH  Output directory path.
               In rewrite:
                 Required *FILE* path.
                 The "rewrite" create a new PBP file to PATH.
                 (It is overwrite the Target_PBP_File by default)
               In extract:
                 Required *DIRECTORY* path.
                 The "extract" extract all files to PATH directory.
                 (And other options is IGNORED)
_USAGE_
}

sub normalize_keys{
	my $args = shift;
	
	my @args_keys = keys %{$args};
	my $pbp_fname = '';
	foreach( @args_keys ){
		detect_keyname:{
			( $_ eq '-p' ) and do{ $pbp_fname = 'param';  last; };
			( $_ eq '-m' ) and do{ $pbp_fname = 'icon0';  last; };
			( $_ eq '-a' ) and do{ $pbp_fname = 'icon1';  last; };
			( $_ eq '-f' ) and do{ $pbp_fname = 'pic0';   last; };
			( $_ eq '-b' ) and do{ $pbp_fname = 'pic1';   last; };
			( $_ eq '-s' ) and do{ $pbp_fname = 'snd0';   last; };
			( $_ eq '-0' ) and do{ $pbp_fname = 'psp';    last; };
			( $_ eq '-1' ) and do{ $pbp_fname = 'psar';   last; };
			
			( $_ eq '-o' ) and do{ last; };
			
			error( "Illegal CONTROL \"_VAR_\"", $_ );
		}
		
		if( $pbp_fname ){
			$args->{$pbp_fname} = $args->{$_} ne 'none' ? $args->{$_} : '';
			$args->{$pbp_fname} =~ tr/\\/\//;
			delete $args->{$_};
		} else{
			$args->{$_} =~ tr/\\/\//;
		}
	}
	
	return 1;
}

sub list{
	my $file = pop || '';
	
	my $Pbp  = PSP::PBPParser->new( $file )->parse_header;
	error( $Pbp->error ) if( $Pbp->error );
	
	printf( '% 10s', 'FILENAME' );
	printf( '% 13s', 'LENGTH(B)' );
	printf( '% 13s', 'LENGTH(MB)' );
	printf( '% 13s', 'OFFSET(DEC)' );
	printf( '% 13s', 'OFFSET(HEX)' );
	print "\n";
	foreach( PBP_DATA_SEQUENCE ){
		next if( not $Pbp->flen( $_ ) );
		printf( '% 10s'   , pbp_name2label( $_ ) );
		printf( '% 13d'   , $Pbp->flen( $_ ) );
		printf( '% 13.2f' , $Pbp->flen( $_ ) / (1024 * 1024) );
		printf( '% 13d'   , $Pbp->foffset( $_ ) );
		printf( '% 13X'   , $Pbp->foffset( $_ ) );
		print "\n";
	}
}

sub create{
	my $new_pbp_path = pop;
	
	error("Not enoght \"create\" arguments",) if( scalar( @_ ) % 2 );
	
	my %files = ( @_ );
	delete $files{'-o'} if( exists $files{'-o'} );
	
	my $DummyPBP = File::IOLite->new( $new_pbp_path );
	$DummyPBP->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$DummyPBP->binary;
	$DummyPBP->write( PBP_HEADER . PBP_VERSION );
	$DummyPBP->write( "\x00" x 4 ) foreach( PBP_DATA_SEQUENCE );
	$DummyPBP->close;
	
	rewrite( %files, $new_pbp_path );
}

sub rewrite{
	my $src_pbp_path = pop;
	
	error("Not enoght \"rewrite\" arguments",) if( scalar( @_ ) % 2 );
	
	my %files  = ( @_ );
	normalize_keys( \%files );
	
	if( exists $files{'-o'} ){
		$files{'-o'} ||= '.';
	} else{
		$files{'-o'} = $src_pbp_path;
	}
	
	my $workdir = '';
	{
		if( $files{'-o'} =~ /\// ){
			$workdir = substr( $files{'-o'}, 0, rindex( $files{'-o'}, '/' ) ) || '';
			error( "\"_VAR_\" is not exist", $workdir ) if( not -d $workdir );
		}
		$workdir = '.' if( $workdir eq '' );
	}
	
	my $Srcpbp = PSP::PBPParser->new( $src_pbp_path )->parse_header;
	error( $Srcpbp->error ) if( $Srcpbp->error );
	
	my $Newpbp = PSP::PBPMaker->new( $files{'-o'} );
	my @extract_items;
	my @http_items;
	print "Checking CONTROL:\n";
	foreach( PBP_DATA_SEQUENCE ){
		print "    " . pbp_name2label( $_ ) . ": "; 
		if( exists $files{$_} ){
			if( $files{$_} =~ /^http:\/\// ){
				print "HTTP $files{$_}";
				push( @http_items, $_ ) ;
			} else{
				$Newpbp->set( $_, $files{$_} );
				print ( $files{$_} ? "FILE $files{$_}" : "remove" );
			}
		} elsif( $Srcpbp->flen( $_ ) ){
			push( @extract_items, $_ );
			print "divert"
		} else{
			print "none";
		}
		print "\n";
	}
	
	my $tmpname = time;
	print "Extracting to divert tempfiles:\n" if( scalar( @extract_items ) );
	foreach( @extract_items ){
		$tmpname++;
		$Newpbp->set( $_, "$workdir/ppe_temp_$tmpname" );
		$Srcpbp->output( $_, $Newpbp->get( $_ ) );
		push( @g_tmpfiles, $Newpbp->get( $_ ) );
	}
	print "    " . join( "\n    ", @g_tmpfiles ) . "\n";
	
	print "Downloading files via HTTP:\n" if( scalar( @http_items ) );
	my %download_list;
	foreach( @http_items ){
		$tmpname++;
		$Newpbp->set( $_, "$workdir/ppe_temp_$tmpname" );
		download( "$workdir/ppe_temp_$tmpname", $files{$_} );
		push( @g_tmpfiles, $Newpbp->get( $_ ) );
	}
	
	print "Writing to $files{'-o'}.\n";
	$Newpbp->make || die $Newpbp->error;
}

sub extract{
	my $src_pbp_path = pop;
	my %files;
	
	for( my $i = 0; $i < scalar( @_ ); $i++ ){
		if( substr( $_[$i], 0, 1 ) eq '-' ){
			if( defined $_[$i + 1] and ( substr( $_[$i + 1], 0, 1 ) ne '-' ) ){
				$files{$_[$i]} = $_[$i + 1];
				$i++;
			} else{
				$files{$_[$i]} = '';
			}
		}
	}
	normalize_keys( \%files );
	foreach( keys %files ){
		next if( substr( $_, 0, 1 ) eq '-' );
		$files{$_} = './' . pbp_name2label( $_ ) if( $files{$_} eq '' );
	}
	
	if( exists $files{'-o'} or not scalar( keys %files ) ){
		$files{'-o'} ||= '.';
		error( "\"_VAR_\" is not a directory", $files{'-o'} ) if( not -d $files{'-o'} );
		$files{$_} = $files{'-o'} . '/' . pbp_name2label( $_ ) foreach( PBP_DATA_SEQUENCE );
	} else{
		my $tmp;
		foreach( keys %files ){
			error( "\"_VAR_\" is directory", $files{$_} ) if( -d $files{$_} );
			
			if( $files{$_} =~ /\// ){
				$tmp = substr( $files{$_}, 0, rindex( $files{$_}, '/' ) );
				error( "\"_VAR_\" is not exist", $tmp ) if( not -d $tmp );
			}
		}
	}
	
	my $Pbp = PSP::PBPParser->new( $src_pbp_path )->parse_header;
	error( $Pbp->error ) if( $Pbp->error );
	
	foreach( keys %files ){
		next if( not $Pbp->flen( $_ ) );
		print "Extracting " . pbp_name2label( $_ ) . " to $files{$_} ...\n";
		$Pbp->output( $_, $files{$_} );
	}
}


sub download{
	my $filepath = shift;
	my $uri      = substr( shift, 7 );
	
	my ( $proto, $host, $port, $path );
	$proto = PROTOCOL;
	( $host, $path ) = split( /\//, $uri , 2 );
	( $host, $port ) = split( /:/ , $host, 2 );
	$port = HTTP_PORT if( not defined $port );
	
	print "    Connect to $host:$port/$proto\n";
	my $http_sock = IO::Socket::INET->new(
		PeerAddr => $host,
		PeerPort => $port,
		Proto    => $proto
	);
	
	error("Can not connect to _VAR_:_VAR_/_VAR_", $host, $port, $proto ) if( not ref $http_sock );
	
	binmode( $http_sock );
	
	_http_req( $http_sock, HTTP_METHOD . " /$path " . HTTP_VERSION );
	_http_req( $http_sock, "Host: $host" );
	_http_req( $http_sock, "User-Agent: " . HTTP_USER_AGENT );
	_http_req( $http_sock, "Connection: close" );
	
	_http_req( $http_sock, "" );
	
	$http_sock->flush;
	
	my $http_status = substr( <$http_sock>, 9, 3 );
	error("HTTP access is not successful. Status _VAR_ ", $http_status ) if( $http_status != 200 );
	
	my $clen = 0;
	my $http_head = '';
	1 while( <$http_sock> ne "\x0D\x0A" );
	
	print "    Download /$path to $filepath\n";
	_download_file( $filepath, $http_sock, $clen );
	
	$http_sock->close;
	
	return 1;
}

sub _http_req{ print {$_[0]} join( '', $_[1], "\x0D\x0A" );  }

sub _download_file{
	my $filepath  = shift;
	my $http_sock = shift;
	my $clen      = shift;
	
	my $Tempfile = File::IOLite->new( $filepath );
	$Tempfile->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$Tempfile->binary;
	
	my $buf;
	while( not eof $http_sock ){
		error( "External Error: _VAR_", $Tempfile->error ) if( $Tempfile->error );
		read( $http_sock, $buf, BUFFER_SIZE );
		$Tempfile->write( $buf );
	}
	
	$Tempfile->close;
	
	return 1;
}

END{
	if( scalar( @g_tmpfiles ) ){
		print "Removing tempfiles.\n";
		unlink( @g_tmpfiles );
	}
}

__END__