#!/usr/local/bin/perl

# PSP PBP extractor by Perl
# http://classg.sytes.net

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

#use strict;
#use warnings;
use vars qw( $VERSION );

use Getopt::Std;

use PSP::PBP::Const;
use PSP::PBP::Parser;

$VERSION = "2.0.0";

if( scalar @ARGV < 1 ){
	die <<_USAGE_;
PSP PBP extractor by Perl.

Usage: pbpextract.pl [options] PBP_FILE
 
 options:
    -p PATH    Place of extract for PARAM.SFO
    -i PATH    Place of extract for ICON0.PNG
    -a PATH    Place of extract for ICON1.PNG
    -t PATH    Place of extract for PIC0.PNG
    -b PATH    Place of extract for PIC1.PNG
    -s PATH    Place of extract for SND0.AT3
    -0 PATH    Place of extract for DATA.PSP
    -1 PATH    Place of extract for DATA.PSAR
  
  special option:
    -o DIRECTORY_PATH
               Required DIRECTORY path.
               Extracting all files to DIRECTORY_PATH directory.
               (And other options will IGNORE)
_USAGE_
}

my $src_pbp = pop @ARGV;
die( "$ARGV[0] not found.\n" ) if( not -f $src_pbp );

my %argv;

if( scalar @ARGV ){
	getopts( 'p:i:a:t:b:s:0:1:o:', \%argv ) or exit 1;
} else{
	$argv{'o'} = '.';
}

if( exists $argv{'o'} ){
	die( "$argv{'o'} not found.\n" ) if( not -d $argv{'o'} );
	$argv{$_} = $argv{'o'} foreach( qw( p i a t b s 0 1 ) );
	delete $argv{'o'};
}

my $SRC_PBP = PSP::PBP::Parser->new( $src_pbp );
$SRC_PBP->parse;
die( $SRC_PBP->error . "\n" ) if( $SRC_PBP->error );

my $def_name;
foreach( keys %argv ){
	$argv{$_} =~ s/\\/\//g;
	$def_name = opt2name( $_ );
	
	next if( not $SRC_PBP->len( $def_name ) );
	
	if( -d $argv{$_} ){
		$argv{$_} = $argv{$_} . '/' . $def_name;
	}
	
	printf( "Extracting %s to %s...", $def_name, $argv{$_} );
	$SRC_PBP->fdump( $def_name, $argv{$_} );
	printf( "done.\n" );
}

__END__